const fs = require("fs");
const path = require("path");
const {defaultLog,readStudy}=require('./read-study.cjs');

const log = process.argv[2] || defaultLog();
const f = Math.fround;
const A = (a, b) => f(f(a) + f(b));
const S = (a, b) => f(f(a) - f(b));
const M = (a, b) => f(f(a) * f(b));
const D = (a, b) => f(f(a) / f(b));
const clamp = (value, low, high) => Math.max(low, Math.min(high, value));
const floor = Math.trunc;

function normalize(snapshot, options = {}) {
    const constant = offset => f(snapshot.constants[offset / 4]);
    const players = snapshot.players;
    const participantCount = players.filter(player => player.v[4] > player.v[3]).length;
    if (!participantCount) return [];

    const density = players.map(player => player.v[4] > player.v[3]
        ? D(player.v[6], Math.max(45, player.v[4] - player.v[3]))
        : 0);
    // The executable initializes both extrema from team 0 / slot 0.
    // That scratch entry is zero when the slot did not participate.
    const initialIndex = players.findIndex(player => player.v[0] === 0 && player.v[1] === 0);
    const initial = initialIndex < 0 ? 0 : density[initialIndex];
    let low = Math.min(initial, ...density);
    let high = Math.max(initial, ...density);
    let sum = 0;
    for (const value of density) sum = A(sum, value);
    const mean = D(sum, participantCount);
    const mean01 = mean <= low ? 0 : mean >= high ? 1 : D(S(mean, low), S(high, low));
    const range = S(high, low);
    high = S(high, M(range, 0.15));
    low = S(low, M(range, 0.1));
    const t = clamp(S(mean01, 0.1), f(0.3), f(0.7));
    const middle = A(M(S(high, low), t), low);
    const scorerCount = [0, 0];
    const maxGoals = [0, 0];
    for (const player of players) {
        if (player.s[0] > 0) {
            scorerCount[player.v[0]]++;
            maxGoals[player.v[0]] = Math.max(maxGoals[player.v[0]], player.s[0]);
        }
    }
    const scale = Math.max(1, D(floor(snapshot.duration), 10));

    return players.map((player, index) => {
        const values = player.v;
        const stats = player.s;
        const minutes = values[4] - values[3];
        const participation = minutes <= 5 ? 0 : minutes >= 45 ? 1 : D(S(minutes, 5), 40);
        let relative = density[index];
        relative = relative > middle
            ? M(clamp(relative >= high ? 1 : D(S(relative, middle), S(high, middle)), 0, 1), 0.5)
            : M(clamp(relative <= low ? 0 : relative >= middle ? 1 : D(S(relative, low), S(middle, low)), 0, 1), -0.5);
        const normalized = A(M(A(M(participation, 0.5), 0.5), relative), 0.5);
        let base = M(S(constant(0x38), constant(0x40)), normalized);
        const continuousBase = A(base, constant(0x40));
        base = D(floor(M(A(A(M(floor(A(base, base)), 0.5), constant(0x40)), 0.05), 10)), 10);
        base = clamp(base, constant(0x40), constant(0x38));
        let note = base;
        let bonus = 0;

        if (stats[0]) {
            if (stats[0] >= floor(M(scale, 6))) bonus = constant(0x20);
            else if (stats[0] >= floor(M(scale, 3))) bonus = constant(0x1c);
            else if (scorerCount[values[0]] >= 2 && stats[0] >= 2 && stats[0] >= maxGoals[values[0]]) bonus = constant(0x10);
            else if (stats[0] >= floor(A(scale, scale))) bonus = constant(0x18);
        }
        if (bonus) note = A(note, bonus);
        if (stats[4] >= floor(A(scale, scale)) || stats[4] >= floor(M(scale, 3))) {
            note = A(note, constant(8));
            bonus = 1;
        } else if (!bonus && (stats[0] || stats[4])) {
            note = A(note, constant(0x14));
            bonus = 1;
        }

        let goalkeeper = 0;
        if (stats[133] && stats[132] && stats[132] >= floor(M(scale, 4))) {
            const ratio = D(stats[133], stats[132]);
            const enemy = snapshot.score[1 - values[0]];
            const own = snapshot.score[values[0]];
            if (own >= enemy && enemy <= floor(scale) && ratio > 0.5) goalkeeper = constant(0x28);
            else if (enemy && enemy >= floor(M(scale, 3)) && ratio < f(0.3)) goalkeeper = constant(0x24);
        }
        if (goalkeeper) note = A(note, goalkeeper);
        else if (!bonus) {
            let threshold = values[5] > 7 && values[5] <= 12 ? 0.3 : 0.2;
            if (stats[24] && D(stats[95], stats[24]) > f(threshold)) note = A(note, constant(0x30));
            threshold = values[5] >= 5 && values[5] <= 12 ? 0.3 : 0.2;
            const lost = stats[90] + stats[91] + stats[92] + stats[93];
            if (stats[65] && D(lost, stats[65]) > f(threshold)) note = A(note, constant(0x2c));
        }

        let extra = 0;
        if (values[9] && values[10]) {
            const ratio = D(values[10], values[9]);
            const offset = ratio >= 1 ? 0x268 : ratio >= f(0.9) ? 0x28c : ratio >= f(0.8) ? 0x288
                : ratio >= f(0.7) ? 0x284 : ratio >= f(0.6) ? 0x280 : ratio >= 0.5 ? 0x27c
                    : ratio >= f(0.4) ? 0x278 : ratio >= f(0.3) ? 0x274 : ratio >= f(0.2) ? 0x270
                        : ratio >= f(0.1) ? 0x26c : 0;
            if (offset) extra = constant(offset);
            if (extra > 0) note = S(note, extra);
        }
        note = clamp(note, constant(0x264), constant(0x260));
        if (minutes < 5) note = 0;
        return {
            id: values[2],
            team: values[0],
            slot: values[1],
            predicted: note,
            engine: values[7],
            actual: values[8],
            difference: S(note, values[7]),
            ...(options.trace ? {trace: {rawPoints: values[6], density: density[index],
                normalized, continuousBase, quantizedBase: base,
                finalAdjustment: S(note, base), minutes}} : {}),
        };
    });
}

function readSnapshots(logPath) {
    return readStudy(logPath).snapshots;
}

if (require.main === module) {
const snapshots = readSnapshots(log);
console.log(`Snapshots ${snapshots.length}`);
for (const snapshot of snapshots) {
    const result = normalize(snapshot);
    const differences = result.filter(player => Math.abs(player.difference) >= 0.01);
    let own = result.find(player => player.id === 2147483834);
    let ownLookup = "exact-id";
    if (!own && !snapshot.schema) {
        own = result.find(player => player.team === 1 && player.slot === 1);
        ownLookup = own ? "legacy-slot-fallback" : "not-found";
    }
    console.log(JSON.stringify({
        schema: snapshot.schema || 1,
        stableReads: snapshot.stable_reads === 1 || snapshot.coherent === 1,
        synchronizedWithCalculation: false,
        time: snapshot.time,
        score: snapshot.score,
        matched: result.length - differences.length,
        total: result.length,
        ownLookup,
        own,
        differences,
    }));
}
}

module.exports = { normalize, readSnapshots };
