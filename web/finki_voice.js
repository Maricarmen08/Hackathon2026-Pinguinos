// Voz en el navegador con el reconocimiento de Chrome/Edge (Web Speech API).
// Dart lo usa desde lib/v1/web_voice_web.dart. Siempre responde con texto:
//   "OK:<lo que se dijo>"  o  "ERR:<codigo>"
(function () {
  var current = null;
  function Recognition() { return window.SpeechRecognition || window.webkitSpeechRecognition; }
  function language() {
    var l = (navigator.language || '').toLowerCase();
    return l.indexOf('es') === 0 ? navigator.language : 'es-PE';
  }

  window.finkiVoice = {
    supported: function () { return !!Recognition(); },

    // onPartial(texto): texto parcial. onReady(): el micrófono ya está escuchando.
    listen: function (onPartial, onReady) {
      return new Promise(function (resolve) {
        var R = Recognition();
        if (!R) { resolve('ERR:UNSUPPORTED'); return; }
        if (current) { try { current.abort(); } catch (e) {} }
        var rec = new R(), finals = '', interim = '', error = null, cancelled = false,
            heard = false, silence = null, limit = null, finished = false;
        current = { abort: function () { cancelled = true; try { rec.abort(); } catch (e) {} },
                    stop: function () { try { rec.stop(); } catch (e) {} } };
        rec.lang = language();
        rec.continuous = true;
        rec.interimResults = true;
        rec.maxAlternatives = 1;

        function finish() {
          if (finished) return;
          finished = true;
          clearTimeout(silence); clearTimeout(limit);
          current = null;
          if (cancelled) { resolve('ERR:CANCELLED'); return; }
          var text = (finals + ' ' + interim).replace(/\s+/g, ' ').trim();
          if (text) { resolve('OK:' + text); return; }
          resolve('ERR:' + (error || 'NO_SPEECH'));
        }
        // Si la persona calla unos segundos después de hablar, se cierra sola.
        function armSilence() {
          clearTimeout(silence);
          silence = setTimeout(function () { try { rec.stop(); } catch (e) {} }, 3500);
        }

        rec.onstart = function () { if (onReady) onReady(); };
        rec.onresult = function (event) {
          heard = true;
          finals = ''; interim = '';
          for (var i = 0; i < event.results.length; i++) {
            var r = event.results[i];
            if (r.isFinal) finals += ' ' + r[0].transcript; else interim += ' ' + r[0].transcript;
          }
          var shown = (finals + ' ' + interim).replace(/\s+/g, ' ').trim();
          if (onPartial) onPartial(shown);
          armSilence();
        };
        rec.onerror = function (event) {
          var e = event && event.error;
          if (e === 'not-allowed' || e === 'service-not-allowed') error = 'PERMISSION_REQUIRED';
          else if (e === 'audio-capture') error = 'MIC_UNAVAILABLE';
          else if (e === 'network') error = 'NETWORK';
          else if (e === 'no-speech') error = 'NO_SPEECH';
          else if (e === 'aborted') cancelled = cancelled || false;
          else error = 'FAILED';
        };
        rec.onend = finish;
        limit = setTimeout(function () { try { rec.stop(); } catch (e) {} }, 45000);
        // Si pasan 8 segundos sin que se diga nada, se cierra.
        silence = setTimeout(function () { if (!heard) { try { rec.stop(); } catch (e) {} } }, 8000);
        try { rec.start(); } catch (e) { error = 'FAILED'; finish(); }
      });
    },
    stop: function () { if (current) current.stop(); },
    cancel: function () { if (current) current.abort(); }
  };
})();
