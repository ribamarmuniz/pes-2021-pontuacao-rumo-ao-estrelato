const fs=require('fs'),path=require('path'),crypto=require('crypto');
const read=name=>JSON.parse(fs.readFileSync(path.join(__dirname,name+'.json'),'utf8').replace(/^\uFEFF/,''));
const pkg=read('package-validation'),live=read('live-validation'),probe=read('event-probe-selftest');
const contextProbe=read('event-context-selftest'),embeddedContext=read('embedded-context-selftest');
const observed=read('observed-context-live-validation'),luaObserved=read('observed-lua-selftest'),luaDecoder=read('context-decoder-lua-selftest');
const compression=read('context-compression-selftest'),archive=read('context-archive-selftest'),instant=read('instant-model-validation');
const moduleHash=crypto.createHash('sha256').update(fs.readFileSync(path.join(__dirname,'..','modules','bal_painel.lua'))).digest('hex');
if(pkg.version!=='0.12'||pkg.moduleSha256.toLowerCase()!==moduleHash||probe.moduleSha256!==moduleHash||!pkg.filesMatch)throw Error('Package differs from validated source');
if(!probe.passed||!contextProbe.passed||!embeddedContext.passed||!luaObserved.passed||!luaDecoder.passed||!compression.passed||!archive.passed||instant.status!=='compared'||instant.failures.length)throw Error('A selftest or model comparison failed');
if(live.status!=='compared'||Object.values(live.validators).some(v=>v.exitCode!==0)||live.observedContextExplanations<1)throw Error('Consolidated live validation is incomplete');
if(observed.status!=='compared'||observed.explanations<1||observed.failures.length)throw Error('Observed-context live validation is incomplete');
const report={version:'0.12',date:new Date().toISOString(),mode:'native-event-marginals-at-observed-context',
 historicalActionAttributionValidated:false,physicalActionValidated:false,observedContextConditionalEffectsValidated:true,
 package:pkg,moduleSha256:moduleHash,runtimeSession:live.session,liveExplanationValidation:live,observedContextLiveValidation:observed,
 nativeProbeSelftest:probe,fullContextProbeSelftest:contextProbe,embeddedContextSelftest:embeddedContext,
 luaObservedContextSelftest:luaObserved,luaContextDecoderSelftest:luaDecoder,compressionSelftest:compression,archiveSelftest:archive,
 instantModelValidation:instant,normalizerValidation:read('native-validation'),rawInterpreterValidation:read('native-raw-validation'),
 limitations:['The measured value is conditional on the complete observed state at a native event boundary.',
  'A native event boundary does not by itself establish one unique physical action.',
  'The result is not a universal fixed bonus for an action.',
  'The original note displayed by the panel remains the value read from the game.']};
fs.writeFileSync(path.join(__dirname,'release-validation.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({version:report.version,packageHash:pkg.sha256,moduleSha256:moduleHash,
 observedContextExplanations:live.observedContextExplanations,validatedPackets:observed.packets,validatedNotes:observed.notes,
 historicalActionAttributionValidated:false,physicalActionValidated:false},null,2));
