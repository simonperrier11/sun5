/*
Author : Simon Perrier
Version : v1.0
Description : This is my first full SuperCollider track called "sun5".
*/

/*
######################
### INITIAL CONFIG ###
######################
*/

Server.killAll;

(
Server.default.options.inDevice_("Built-in Microph");
Server.default.options.outDevice_("Built-in Output");
Server.default.options.sampleRate = 44100;
s.boot;
)

TempoClock.default.tempo = (160/60);
Buffer.freeAll;
~b = "audio/*.wav".resolveRelative.pathMatch.collect({ |path| Buffer.read(s, path) });

/*
###################
### INSTRUMENTS ###
###################
*/

// For percussions, I've adapted some examples found here https://sccode.org/1-523
// and here https://sccode.org/1-54H

(
// Kick drum
SynthDef.new(\kick, {
	arg out = 0, pan = 0, amp = 0.7, lowFreqMidpoint = 150;
	var sig, low, lowFreqEnv, lowAmpEnv, mid, midFreqEnv, midAmpEnv;

	// Main body
	lowFreqEnv = EnvGen.ar(Env([250, lowFreqMidpoint, 50], [0.03, 0.1], curve: \exp));
	lowAmpEnv = EnvGen.ar(Env.linen(0.005, 0.1, 0.3), doneAction: 2);
	low = SinOsc.ar(lowFreqEnv) * lowAmpEnv;

	// Add pop
	midFreqEnv = EnvGen.ar(Env([800, 240], [0.02], curve: \exp));
	midAmpEnv = EnvGen.ar(Env.linen(0.001, 0.02, 0.001));
	mid = SinOsc.ar(midFreqEnv) * midAmpEnv;

	// Add and smooth signals
	sig = low + mid;
	sig = sig.tanh;

	sig = Pan2.ar(sig, pan, amp);

	Out.ar(out, sig);
}).add;

// Snare drum
SynthDef.new(\snare, {
	arg out = 0, pan = 0, amp = 0.8, noiseEnvRel = 0.3, hitStartFreq = 3000, hitMidFreq = 600, hitEndFreq = 150;
	var sig, hit, hitAmpEnv, hitFreqEnv, noise, noiseAmpEnv;

	// Main body
	hitFreqEnv = EnvGen.ar(Env([hitStartFreq, hitMidFreq, hitEndFreq], [0.005, 0.01], curve: \exp));
	hitAmpEnv = EnvGen.ar(Env.perc(0.01, 0.08));
	hit = SinOsc.ar(hitFreqEnv) * hitAmpEnv;

	// Add noise
	noiseAmpEnv = EnvGen.ar(Env.perc(0.001, noiseEnvRel), doneAction: 2);
	noise = BPF.ar(WhiteNoise.ar, 900, 1.5) * noiseAmpEnv;

	sig = hit + noise;

	sig = Pan2.ar(sig, pan, amp + 0.7);

	Out.ar(out, sig);
}).add;

// Hi hat
SynthDef.new(\hihat, {
	arg out = 0, amp = 0.15, pan = 0, att = 0.01, rel = 0.2, filterFreq = 6000;
	var filterEnv, sig;

	// Filtered white noise (with percussive env)
	sig = WhiteNoise.ar;
	filterEnv = EnvGen.kr(Env.perc(att, rel, amp), doneAction: 2);
	sig = HPF.ar(sig, filterFreq, filterEnv);

	sig = Pan2.ar(sig, pan);

	Out.ar(out, sig);
}).add;

// Small ding noise
SynthDef(\ding, {
	arg out = 0, amp = 0.9, freq = 5000, pan = 0;
	var sig, env;

	env = EnvGen.kr(Env.perc(0.01, 0.02), doneAction: 2);
	sig = SinOsc.ar(freq) * env;

	sig = Pan2.ar(sig, pan);

	Out.ar(out, sig * amp);
}).add;

// Reverberated clap
SynthDef(\clap, {
	arg out = 0, amp = 0.9, freq = 2000, rq = 0.8, pan = 0;
	var sig, env;

	env = EnvGen.kr(Env.perc(0.01, 4), doneAction: 2);

	sig = WhiteNoise.ar();
	sig = RLPF.ar(sig, freq, rq);
	sig = BLowShelf.ar(sig, 200, 1, 10);

	// Add small delay + reverb for ample effect
	sig = DelayC.ar(sig, 0.75, 0.75);
	sig = FreeVerb.ar(sig, 0.8, 0.7);

	sig = sig * env;
	sig = Pan2.ar(sig, pan, 0.9);

	Out.ar(out, sig * (amp + 1.7));
}).add;

// For main melody
SynthDef(\moogsynth, {
	arg out = 0, amp = 0.1, freq1 = 40, freq2 = 120, width1 = 0.3, width2 = 0.7,
	    filterFreq = 4200, filterGain = 0.5, att = 0.01, rel = 2, waveType = 0;
	var sig, env;

	env = EnvGen.kr(Env.perc(att, rel), doneAction: 2);

	// Variable wavetype
	sig = Select.ar(
		waveType,
		[
			// Slight detuning applied
			Pulse.ar([freq1 * {1 + Rand.new(0.0, 0.0001)}, freq2 + Rand.new(0.0, 0.0001)]!8, [width1, width2]!8),
			VarSaw.ar([freq1 * {1 + Rand.new(0.0, 0.0001)}, freq2 + Rand.new(0.0, 0.0001)]!8, width: [width1, width2]!8)
		]
	);

	// Classic moog filtering
	sig = MoogFF.ar(sig * env, filterFreq, filterGain);

	sig = Splay.ar(sig, 0.1);

	// Add some reverb
	sig = FreeVerb.ar(sig, 0.33, 0.9, 0.1, 1);

	Out.ar(out, sig * amp);
}).add;

// Bass with modulated filter sweep
SynthDef(\bass, {
	arg out = 0, amp = 0.5, freq = 80, width = 0.8, filterFreq = 1200, filterSpeed = 2, filterQ = 0.9;
	var sig, env, filterSpdAccel, filterLfo;

	env = EnvGen.kr(Env.linen(0.01, 1.2, 0.6, 0.6, \welch), doneAction: 2);
	sig = VarSaw.ar(freq, 0, width);

	// Variable speed and acceleration
	filterSpdAccel = LFTri.kr(exprand(0.1, 0.9)).exprange(0.1, 0.9);
	filterLfo = LFTri.kr(filterSpeed * filterSpdAccel).exprange(0.1, 0.9);

	sig = RLPF.ar(sig, filterFreq * filterLfo, filterQ);
	sig = sig * env;

	sig = Pan2.ar(sig);

	Out.ar(out, sig * amp);
}).add;

// Sampler for ambiant pad-like effect
SynthDef.new(\samplersynth, {
	arg bufnum, out = 0, rate = 1.0, pos = 0.0, pan = 0.0, amp = 0.01, filterFreq = 700;
	var sig, env;

	//  Variable amplitude
	env = EnvGen.kr(Env.sine(3), levelScale: amp, doneAction: 2);

	sig = PlayBuf.ar(
		numChannels: 2,
		bufnum: bufnum,
		rate: rate * BufRateScale.kr(bufnum),
		trigger: 1.0,
		startPos: pos * BufFrames.kr(bufnum),
		loop: 0,
		doneAction: 2
	);

	// Slight filtering
	sig = LPF.ar(sig, filterFreq);

	sig = FreeVerb.ar(sig, 0.5, 0.9, 0.1, 1.2);

	sig = Pan2.ar(sig, pan, 0.8);

	Out.ar(out, sig);
}).add;
)

/*
################
### PATTERNS ###
################
*/

(
~kick_line = Pdef(\kick_line, Pbind(
	\instrument, \kick,
	\lowFreqMidpoint, Pseq([200, 150, 100, 50], inf),
	\amp, 0.3,
	\dur, Pseq(
		[
			// Start off relaxed, then more kicks; end relaxed again
			Pseq([4], 32),
			Pseq([2], 64),
			Pseq([1], 256),
			Pseq([4], 16),
	], 1),
));
~kick_line.trace.play(quant: Quant.new(4));

~bass_line = Pdef(\bass_line, Pbind(
	\instrument, \bass,
	\dur, 4,
	\amp, 0.6,
	\width, Pwhite(0.1, 0.3, inf),
	\filterFreq, Pwhite(800, 1000, inf),
	\filterSpeed, Prand([3, 4, 5], inf),
	\filterQ, Pwhite(0.5, 0.8, inf),
	\freq, Pseq(
		[
			// 2 main parts for the bass
			Pseq([40, 40, 80, 40, 60, 60, 30, 60, 50, 100, 50, 50, 50, 50, 50, 56], 4),
			Pseq([40, 40, 80, 40, 60, 57, 30, 60, 50, 100, 50, 50, 100, 50, 100, 112], 5),
	], 1),
));
~bass_line.trace.play(quant: Quant.new(4));

~clap_line = Pdef(\clap_line, Pbind(
	\instrument, \clap,
	\amp, 0.8,
	\freq, Pseq(
		[
			Pseq([0], 4), // Silent for a couple of sequences
			Pseq([2000], 6),
	], 1),
	\dur, 64
));
~clap_line.trace.play(quant: Quant.new(4));

~hihat_line = Pdef(\hithat_line, Pbind(
	\instrument, \hihat,
	\rel, Pseq(
		[
			// Allow bigger releases as track progresses
			Prand([0.05, 0.1, 0.2], 128),
			Prand([0.05, 0.1, 0.2, 0.3, 0.9], 64),
			Prand([0.05, 0.1, 0.2, 0.3, 0.9, 1, 1.2, 1.3], inf),
	], 1),
	\dur, Pseq(
		[
			// Allow faster hits as track progresses
			Prand([2, 1], 64),
			Pwrand([2, 1, 0.5], [0.6, 0.3, 0.1], 64),
			Prand([1, 0.5], 512),
	], 1),
	\amp, Pwrand([0.1, 0.4, 0], [0.7, 0.2, 0.1], inf),
	\pan, Pseq([-0.7, -0.4, 0, 0.4, 0.7], inf),
	\filterFreq, Pseq(
		[
			Pseq([6000], 64),
			Prand([2000, 5000, 6000], inf)
	], 1),
));
~hihat_line.trace.play(quant: Quant.new(4));

~snare_line = Pdef(\snare_line, Pbind(
	\instrument, \snare,
	\amp, Pwhite(0.01, 0.15, inf),
	\hitStartFreq, Pwhite(4000, 6000, inf),
	\hitMidFreq, Pwhite(200, 800, inf),
	\hitEndFreq, Pwhite(120, 200, inf),
	\pan, Prand([-0.3, -0.2, -0.1, 0, 0.1, 0.2, 0.3], inf),
	\dur, Pseq(
		[
			Pxrand(
				[
					// Starts with calm patterns
					Pseq([2, 1.5, 0.5], 1),
					Pseq([2.5, 1, 0.5], 1),
			], 64),
			Pxrand(
				[
					// Excited patterns when track picks up
					Pseq([1, 0.5, 1, 0.5, 1], 1),
					Pseq([0.5, 2.5, 0.5, 0.5], 1),
					Pseq([0.5, 0.5, 2, 1], 1),
					Pseq([0.25, 0.25, 0.5, 1, 0.25, 0.5, 0.25, 1], 1),
					Pseq([1, 0.25, 0.5, 0.25, 1, 0.5, 0.5], 1),
					Pseq([1.5, 2, 0.5], 1),
					Pseq([0.5, 1, 1, 0.5, 1], 1),
					Pseq([0.5, 0.25, 0.25, 0.5, 1.5, 1], 1),
					/*
					The secret sauce : half duration to offset all patterns!
					Adds interesting variations
					*/
					Pseq([0.5], 1)
			], 68),
	], 1),
	\noiseEnvRel, Pseq(
		[
			Pwhite(0.05, 0.1, 144),
			Pwhite(0.07, 0.25, inf)
	], 1)
));
~snare_line.trace.play(quant: Quant.new(4));

~ding_line = Pdef(\ding_line, Pbind(
	\instrument, \ding,
	\freq, Pseq(
		[
			// Silent at beginning
			Pseq([0], 128),
			Pwhite(3000, 6000, 512).round(250),
	], 1),
	\dur, Pseq(
		[
			// Silent at beginning, then 2 different patterns
			Pseq([1], 128),
			Pseq([1.5, 1.5, 1.5, 2, 0.5, 0.5, 0.5, 1], 16),
			Pseq([0.5, 0.5, 1, 1, 0.5, 0.5, 0.25, 0.25, 0.5, 1, 1, 0.5, 0.5], 64),
	], 1),
	\pan, Pwhite(-0.1, 0.1, inf)
));
~ding_line.trace.play(quant: Quant.new(4));

~freq1Values = [[40, 80, 120, 20], [60, 180, 60, 240], [200, 100, 50, 50], [50, 100, 50, 200]];
~freq2Values = [[120, 160, 200, 100], [150, 300, 150, 300], [265, 530, 132.5, 265], [240, 480, 120, 240]];

~moogsynth_line = Pdef(\moogsynth_line, Pbind(
	\instrument, \moogsynth,
	\dur, 0.5,
	\amp, Pseq(
		[
			// Allow more mute notes at beginning and end
			Pwrand([0, 0.1], [0.25, 0.75], 256),
			Pwrand([0, 0.15], [0.08, 0.92], 768),
			Pwrand([0, 0.1], [0.4, 0.6], inf),
		], 1),
	\filterFreq, Pseq(
		[
			// Gradually open up filter, then close it back
			Pwhite(800, 900, 128),
			Pwhite(900, 1200, 128),
			Pwhite(1200, 2000, 128),
			Pwhite(2000, 3000, 640),
			Pwhite(400, 1000, 256)
	], 1),
	\freq1, Pseq(
		[
			Pseq(
				[
					Pseq(~freq1Values[0], 8),
					Pseq(~freq1Values[1], 8),
					Pseq(~freq1Values[2], 8),
					Pseq(~freq1Values[3], 8),
			], 2),
			Pseq(
				[
					Pseq(~freq1Values[0] * 2, 8),
					Pseq(~freq1Values[1] * 2, 8),
					Pseq(~freq1Values[2] * 2, 8),
					Pseq(~freq1Values[3] * 2, 8),
			], 6),
			Pseq(
				[
					Pseq(~freq1Values[0] * 3, 8),
					Pseq(~freq1Values[1] * 3, 8),
					Pseq(~freq1Values[2] * 3, 8),
					Pseq(~freq1Values[3] * 3, 8),
			], 2),
	], 1),
	\freq2, Pseq(
		[
			Pseq(
				[
					Pseq(~freq2Values[0], 8),
					Pseq(~freq2Values[1], 8),
					Pseq(~freq2Values[2], 8),
					Pseq(~freq2Values[3], 8),

			], 2),
			Pseq(
				[
					Pseq(~freq2Values[0] * 2, 8),
					Pseq(~freq2Values[1] * 2, 8),
					Pseq(~freq2Values[2] * 2, 8),
					Pseq(~freq2Values[3] * 2, 8),
			], 4),
			Pseq(
				[
					Pseq(~freq2Values[0] * 3, 8),
					Pseq(~freq2Values[1] * 3, 8),
					Pseq(~freq2Values[2] * 3, 8),
					Pseq(~freq2Values[3] * 2, 8),
			], 2),
			Pseq(
				[
					Pseq(~freq2Values[0] * 3, 8),
					Pseq(~freq2Values[1] * 3, 8),
					Pseq(~freq2Values[2] * 3, 8),
					Pseq(~freq2Values[3] * 3, 8),
			], 2),
	], 1),
	\att, Pwhite(0.05, 0.07, inf),
	\rel, Pwhite(1.8, 2.5, inf),
	\width1, Pwhite(0.25, 0.35, inf),
	\width2, Pwhite(0.65, 0.75, inf),
	\filterGain, Pseq(
		[
			// Higher gain has more weight as track progresses
			Pwrand([0.1, 0.5, 1], [0.6, 0.3, 0.1], 64),
			Pwrand([0.1, 0.5, 1, 1.2], [0.1, 0.1, 0.6, 0.2], inf)
	], 1),
	\waveType, Pfunc({
		arg self;
		// Switch synth wavetype somewhat randomly
		if (self.filterFreq > 1500, {2.rand}, {0});
	})
));
~moogsynth_line.trace.play(quant: Quant.new(4));

~ambiant_pad = Pdef(\ambiant_pad, Pbind(
	\instrument, \samplersynth,
	\bufnum, ~b[0].bufnum, // Read first audio file in buffer
	\dur, 0.5,
	\amp, 1,
	\filterFreq, Pseq([
		// Filter is loosened as track progresses
		Pseq([500], 64),
		Pseq([750], 64),
		Pseq([1000], inf)
	], 1),
	\rate, Pseq(
		[
			Pseq([10.6.midiratio], 32),
			Pseq([1.5.midiratio], 32),
			Pseq([3.2.midiratio], 32),
			Pseq([1.5.midiratio], 32),
	], 5),
	\pos, Pseg([0.1, 0.7, 0.2], ~b[0].duration, \lin, inf),
	\pan, Pseg([-0.2, 0, 0.2, 0], [2, 4, 2], \lin, inf)
));

// Start ambiant pad more towards the second part of the track
~ambiant_pad.trace.play(quant: Quant.new(4, 256));
)
