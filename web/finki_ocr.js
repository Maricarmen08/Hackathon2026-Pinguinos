// Lectura de fotos dentro del navegador (Tesseract.js, todo se sirve desde este mismo sitio).
// Dart lo usa desde lib/v1/web_ocr_web.dart. Siempre responde con texto:
//   "OK:<texto leído>"  o  "ERR:<codigo>"
(function () {
  var state = { loading: null, worker: null };
  function url(path) { return new URL('finki_ocr/' + path, document.baseURI).href; }

  function loadScript(src) {
    return new Promise(function (resolve, reject) {
      var s = document.createElement('script');
      s.src = src; s.async = true;
      s.onload = resolve;
      s.onerror = function () { reject(new Error('script')); };
      document.head.appendChild(s);
    });
  }

  function getWorker() {
    if (state.worker) return Promise.resolve(state.worker);
    if (state.loading) return state.loading;
    state.loading = loadScript(url('tesseract.min.js')).then(function () {
      return window.Tesseract.createWorker('spa', 1, {
        workerPath: url('worker.min.js'),
        corePath: url('core'),
        langPath: url('lang'),
        gzip: true,
        cacheMethod: 'none'
      });
    }).then(function (w) {
      state.worker = w;
      return w;
    }).catch(function (e) {
      state.loading = null;
      throw e;
    });
    return state.loading;
  }

  // Reduce fotos grandes y las pasa a gris con más contraste: más rápido y más legible.
  function prepare(bytes) {
    var blob = new Blob([bytes]);
    return createImageBitmap(blob).then(function (bmp) {
      var max = 1800, scale = Math.min(1, max / Math.max(bmp.width, bmp.height));
      var w = Math.max(1, Math.round(bmp.width * scale)), h = Math.max(1, Math.round(bmp.height * scale));
      var canvas = document.createElement('canvas');
      canvas.width = w; canvas.height = h;
      var ctx = canvas.getContext('2d', { willReadFrequently: true });
      ctx.fillStyle = '#fff'; ctx.fillRect(0, 0, w, h);
      ctx.drawImage(bmp, 0, 0, w, h);
      if (bmp.close) bmp.close();
      var img = ctx.getImageData(0, 0, w, h), d = img.data, lo = 255, hi = 0, i, g;
      for (i = 0; i < d.length; i += 4) {
        g = (d[i] * 0.299 + d[i + 1] * 0.587 + d[i + 2] * 0.114) | 0;
        d[i] = d[i + 1] = d[i + 2] = g;
        if (g < lo) lo = g;
        if (g > hi) hi = g;
      }
      var range = Math.max(1, hi - lo);
      if (range < 200) {
        for (i = 0; i < d.length; i += 4) {
          g = Math.min(255, Math.max(0, ((d[i] - lo) * 255 / range) | 0));
          d[i] = d[i + 1] = d[i + 2] = g;
        }
      }
      ctx.putImageData(img, 0, 0);
      return canvas;
    });
  }

  window.finkiOcr = {
    supported: function () {
      return typeof Worker !== 'undefined' && typeof WebAssembly !== 'undefined' &&
        typeof createImageBitmap !== 'undefined';
    },
    read: function (bytes) {
      var done = false;
      var timeout = new Promise(function (resolve) {
        setTimeout(function () { if (!done) resolve('ERR:TIMEOUT'); }, 90000);
      });
      var work = prepare(bytes).then(function (canvas) {
        return getWorker().then(function (w) { return w.recognize(canvas); });
      }).then(function (r) {
        return 'OK:' + ((r && r.data && r.data.text) || '');
      }).catch(function (e) {
        return 'ERR:' + ((e && e.message) === 'script' ? 'LOAD' : 'FAILED');
      });
      return Promise.race([work, timeout]).then(function (v) { done = true; return v; });
    }
  };
})();
