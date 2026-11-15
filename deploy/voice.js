// Voice chat for Yes, Captain! Players in a crew room talk directly to each other (WebRTC, audio only).
// The game passes the small handshake messages between players through its own connection to the server;
// the sound itself never goes through the server (unless a TURN relay is configured in config.js).
window.YCVoice = (function () {
	'use strict';
	let stream = null;
	let me = 0;
	let on = false;
	let muted = false;
	let error = '';
	let starting = false;
	let wanted = [];
	let ctx = null;
	let myMeter = null;
	const peers = {}; // id -> {pc, audio, meter, connected, queue}

	function ice() {
		const extra = (window.YC_ICE && Array.isArray(window.YC_ICE)) ? window.YC_ICE : [];
		return { iceServers: [{ urls: 'stun:stun.l.google.com:19302' }].concat(extra) };
	}

	function supported() {
		return !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia && window.RTCPeerConnection && window.isSecureContext);
	}

	function why() {
		if (!window.isSecureContext) { return 'Voice needs an https address.'; }
		if (!window.RTCPeerConnection || !navigator.mediaDevices) { return 'This browser has no voice chat.'; }
		return '';
	}

	function emit(to, obj) {
		if (typeof api.onSend === 'function') { api.onSend(to, JSON.stringify(obj)); }
	}

	function meter(s) {
		try {
			if (!ctx) { ctx = new (window.AudioContext || window.webkitAudioContext)(); }
			if (ctx.state === 'suspended') { ctx.resume(); }
			const src = ctx.createMediaStreamSource(s);
			const an = ctx.createAnalyser();
			an.fftSize = 256;
			src.connect(an);
			return { an: an, buf: new Uint8Array(an.fftSize) };
		} catch (e) { return null; }
	}

	function level(m) {
		if (!m) { return 0; }
		m.an.getByteTimeDomainData(m.buf);
		let peak = 0;
		for (let i = 0; i < m.buf.length; i++) { peak = Math.max(peak, Math.abs(m.buf[i] - 128)); }
		return Math.min(1, peak / 60);
	}

	function drop(id) {
		const p = peers[id];
		if (!p) { return; }
		try { p.pc.close(); } catch (e) {}
		if (p.audio) { p.audio.srcObject = null; p.audio.remove(); }
		delete peers[id];
	}

	function make(id) {
		const pc = new RTCPeerConnection(ice());
		const p = { pc: pc, audio: null, meter: null, connected: false, queue: [], remoteSet: false };
		peers[id] = p;
		if (stream) { stream.getTracks().forEach((t) => pc.addTrack(t, stream)); }
		pc.onicecandidate = (e) => { if (e.candidate) { emit(id, { c: e.candidate }); } };
		pc.ontrack = (e) => {
			if (!p.audio) {
				p.audio = document.createElement('audio');
				p.audio.autoplay = true;
				p.audio.style.display = 'none';
				document.body.appendChild(p.audio);
			}
			p.audio.srcObject = e.streams[0];
			p.audio.play().catch(() => {});
			p.meter = meter(e.streams[0]);
		};
		pc.onconnectionstatechange = () => {
			p.connected = pc.connectionState === 'connected';
			if (pc.connectionState === 'failed' && peers[id] === p) {
				drop(id);
				setTimeout(() => { if (on) { connect(); } }, 1500);
			}
		};
		return p;
	}

	async function offer(id) {
		const p = make(id);
		try {
			const o = await p.pc.createOffer();
			await p.pc.setLocalDescription(o);
			emit(id, { sdp: p.pc.localDescription });
		} catch (e) { console.warn('voice offer failed', e); }
	}

	function connect() {
		// the player with the lower number calls the other, so two players never call each other at once
		if (!on || !stream) { return; }
		wanted.forEach((id) => { if (!peers[id] && me < id) { offer(id); } });
		Object.keys(peers).forEach((k) => { if (wanted.indexOf(Number(k)) < 0) { drop(Number(k)); } });
	}

	async function signal(from, json) {
		if (!on || !stream) { return; }
		let d;
		try { d = JSON.parse(json); } catch (e) { return; }
		let p = peers[from];
		try {
			if (d.sdp) {
				if (d.sdp.type === 'offer') {
					if (p) { drop(from); }
					p = make(from);
					await p.pc.setRemoteDescription(d.sdp);
					p.remoteSet = true;
					const a = await p.pc.createAnswer();
					await p.pc.setLocalDescription(a);
					emit(from, { sdp: p.pc.localDescription });
				} else if (p) {
					await p.pc.setRemoteDescription(d.sdp);
					p.remoteSet = true;
				}
				if (p) { for (const c of p.queue) { await p.pc.addIceCandidate(c).catch(() => {}); } p.queue = []; }
			} else if (d.c && p) {
				if (p.remoteSet) { await p.pc.addIceCandidate(d.c).catch(() => {}); } else { p.queue.push(d.c); }
			}
		} catch (e) { console.warn('voice signal failed', e); }
	}

	async function start(myId) {
		me = Number(myId);
		if (on || starting) { return; }
		error = why();
		if (error) { return; }
		starting = true;
		try {
			stream = await navigator.mediaDevices.getUserMedia({ audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true }, video: false });
			stream.getAudioTracks().forEach((t) => { t.enabled = !muted; });
			myMeter = meter(stream);
			on = true;
			error = '';
			connect();
		} catch (e) {
			error = (e && e.name === 'NotAllowedError') ? 'Microphone blocked. Allow it in the address bar.' : 'No microphone found.';
		}
		starting = false;
	}

	function stop() {
		on = false;
		Object.keys(peers).forEach((k) => drop(Number(k)));
		if (stream) { stream.getTracks().forEach((t) => t.stop()); stream = null; }
		myMeter = null;
		wanted = [];
	}

	function setPeers(json) {
		try { wanted = JSON.parse(json).map(Number).filter((n) => n !== me); } catch (e) { wanted = []; }
		connect();
	}

	function setMuted(m) {
		muted = !!m;
		if (stream) { stream.getAudioTracks().forEach((t) => { t.enabled = !muted; }); }
	}

	function state() {
		const out = { on: on, muted: muted, error: error, me: muted ? 0 : level(myMeter), peers: {} };
		Object.keys(peers).forEach((k) => { out.peers[k] = { c: peers[k].connected, l: level(peers[k].meter) }; });
		return JSON.stringify(out);
	}

	const api = { supported: supported, why: why, start: start, stop: stop, setPeers: setPeers, setMuted: setMuted, signal: signal, drop: drop, state: state, onSend: null };
	return api;
}());
