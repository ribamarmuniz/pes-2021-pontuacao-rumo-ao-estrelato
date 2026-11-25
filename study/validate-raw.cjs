const fs = require('fs');
const zlib = require('zlib');
const path = require('path');
const {evaluate} = require('./compiled-program.cjs');
const {defaultLog,readStudy}=require('./read-study.cjs');

const folder = path.resolve(__dirname, '..');
const logPath = process.argv[2] || defaultLog();
const cpkPath = (require.main === module && process.argv[3]) || 'C:\\Games\\PES2021\\Data\\dt18_all.cpk';
const compressed = Buffer.alloc(4817);
const fd = fs.openSync(cpkPath, 'r');
try { fs.readSync(fd, compressed, 0, compressed.length, 4096); }
finally { fs.closeSync(fd); }
const data = zlib.inflateSync(compressed.subarray(16));
const rating = data.subarray(16112, 16112 + 4816).toString('latin1');
const formulas = [...rating.matchAll(/[ -~]{100,}/g)].map(match => match[0]);
if (formulas.length !== 4) throw new Error('Quatro formulas nao encontradas no rating.o');

const statIds = {
    StatsPlayerBallTouch: 67, StatsPlayerShootInFrame: 17, StatsPlayerGoal: 0,
    StatsPlayerPKGoal: 3, StatsPlayerFKGoal: 2, StatsPlayerOwnGoal: 1,
    StatsPlayerAssist: 4, StatsPlayerPassShortSuccess: 25,
    StatsPlayerPassThrouhSuccess: 27, StatsPlayerPassLongSuccess: 29,
    StatsPlayerCenteringSuccess: 31, StatsPlayerPassShort: 24,
    StatsPlayerTackleSuccess: 50, StatsPlayerDispossessDelay: 51,
    StatsPlayerDispossessPress: 52, StatsPlayerClear: 54,
    StatsPlayerFoul: 55, StatsPlayerOffSide: 56,
    StatsPlayerCardYellow: 57, StatsPlayerCardRed: 58,
    StatsPlayerSnatchByPassCut: 78,
    StatsPlayerSnatchByBlock: 86, StatsPlayerSnatchByWedge: 87,
    StatsPlayerSnatchedDuringPass: 94, StatsPlayerShoot: 6,
    StatsPlayerGKSave: 133, StatsPlayerGKShootPA: 134,
    StatsPlayerCutPass: 78,
};
const uniqueIds = {
    UnqStatsPlayerDribbleAttack: 0, UnqStatsPlayerShootShort: 1,
    UnqStatsPlayerShootMiddle: 2, UnqStatsPlayerShootLong: 3,
};
const formulaByCategory = [2, 0, 0, 3, 3, 3, 3, 1, 1, 1];

function resolve(name,player,snapshot) {
    if (Object.hasOwn(statIds, name)) return player.s[statIds[name]];
    if (Object.hasOwn(uniqueIds, name)) return player.u[uniqueIds[name]];
    if (name === 'StatsPlayerSnatchedDuringDribble') return player.s.slice(90, 94).reduce((a, b) => a + b, 0);
    if (name === 'StatsPlayerSnatchByTackle') return player.s[84] + player.s[85];
    const participationScore=snapshot.schema>=5 && player.t ? player.t : snapshot.score;
    if (name === 'StatsTeamMyScore') return participationScore[player.v[0]];
    if (name === 'StatsTeamEnemyScore') return participationScore[1 - player.v[0]];
    if (name === 'StatsTeamWin') return Number(snapshot.score[player.v[0]] > snapshot.score[1 - player.v[0]]);
    throw new Error('Funcao desconhecida ' + name);
}
function calculate(expression, player, snapshot) {
    const tokens = expression.match(/[A-Za-z_][A-Za-z_0-9]*\(\)|(?:\d+\.\d+|\d+)|[()+*\/-]/g) || [];
    let cursor = 0;
    function primary() {
        const token = tokens[cursor++];
        if (token === '(') {
            const value = sum();
            if (tokens[cursor++] !== ')') throw new Error('Parenteses sem fechamento');
            return value;
        }
        if (token === '-') return -primary();
        if (/^\d/.test(token || '')) return Number(token);
        const name = token && token.slice(0, -2);
        return resolve(name,player,snapshot);
    }
    function product() {
        let value = primary();
        while (tokens[cursor] === '*' || tokens[cursor] === '/') {
            const op = tokens[cursor++], right = primary();
            value = op === '*' ? value * right : value / right;
        }
        return value;
    }
    function sum() {
        let value = product();
        while (tokens[cursor] === '+' || tokens[cursor] === '-') {
            const op = tokens[cursor++], right = product();
            value = op === '+' ? value + right : value - right;
        }
        return value;
    }
    const value = sum();
    if (cursor !== tokens.length) throw new Error('Expressao incompleta');
    return value;
}

if (require.main === module) {
const {snapshots,programSets}=readStudy(logPath);
if (programSets.length) {
    const programs = programSets[programSets.length-1];
    const first = programs.map(hex => Buffer.from(hex, 'hex').readFloatLE(4));
    console.log('Programas BE00, CA04, D608, E20C, primeiros coeficientes ' + first.join(', '));
}
for (const snapshot of snapshots) {
    const compiledPrograms=snapshot._programs;
    if (!snapshot.schema || !snapshot.players.every(player => Array.isArray(player.u) && player.v.length >= 12)) continue;
    const results = snapshot.players.filter(player => player.v[4] > player.v[3]).map(player => {
        const category = player.v[11];
        const formulaIndex = formulaByCategory[category];
        const expected = formulaIndex === undefined ? null : calculate(formulas[formulaIndex], player, snapshot);
        const observed = player.v[6];
        const programIndex = [2,0,3,1][formulaIndex];
        const compiled = compiledPrograms && programIndex !== undefined
            ? evaluate(compiledPrograms[programIndex],name=>resolve(name,player,snapshot)) : null;
        const alternatives = formulas.map(formula => calculate(formula, player, snapshot) - observed);
        return { id: player.v[2], category, expected, compiled, observed,
            difference: compiled !== null ? compiled - Math.fround(observed)
                : expected === null ? null : expected - observed, alternatives };
    });
    const matched = results.filter(result => result.compiled !== null && result.difference === 0);
    const mismatched = results.filter(result => result.compiled === null || result.difference !== 0);
    const scoreCandidates = [];
    for (let home = 0; home <= 5; home++) for (let away = 0; away <= 5; away++) {
        const trial = { ...snapshot, score: [home, away] };
        const count = snapshot.players.filter(player => player.v[4] > player.v[3])
            .filter(player => {
                const index = formulaByCategory[player.v[11]];
                return index !== undefined && Math.abs(calculate(formulas[index], player, trial) - player.v[6]) < 0.05;
            }).length;
        scoreCandidates.push({ score: [home, away], matched: count });
    }
    scoreCandidates.sort((a, b) => b.matched - a.matched);
    const scoreAligned = results.length > 0
        && scoreCandidates[0].score[0] === snapshot.score[0]
        && scoreCandidates[0].score[1] === snapshot.score[1];
    const rawPointsMatch = snapshot.schema >= 3 && results.length > 0
        && matched.length === results.length;
    console.log(JSON.stringify({ schema: snapshot.schema, time: snapshot.time, score: snapshot.score,
        matched: matched.length, total: results.length,
        own: results.find(result => result.id === 2147483834),
        bestScoreCandidates: scoreCandidates.slice(0, 4), scoreAligned,
        rawPointsMatch, usableForCausalStudy: false,
        synchronizationVerified: false, mismatched }));
}
console.log('Snapshots analisados ' + snapshots.length);
}
module.exports = {calculate, resolve, formulas, formulaByCategory};
