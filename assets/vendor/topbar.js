/**
 * @license MIT
 * topbar 2.0.0, 2023-02-04
 * https://buunguyen.github.io/topbar
 * Copyright (c) 2021-2023 Buu Nguyen
 */
(function (window, document) {
  "use strict";

  // https://gist.github.com/paulirish/1579671
  (function() {
    var lastTime = 0;
    var vendors = ['ms', 'moz', 'webkit', 'o'];
    for(var x = 0; x < vendors.length && !window.requestAnimationFrame; ++x) {
      window.requestAnimationFrame = window[vendors[x]+'RequestAnimationFrame'];
      window.cancelAnimationFrame = window[vendors[x]+'CancelAnimationFrame'] 
                                 || window[vendors[x]+'CancelRequestAnimationFrame'];
    }
    if (!window.requestAnimationFrame)
      window.requestAnimationFrame = function(callback, element) {
        var currTime = new Date().getTime();
        var timeToCall = Math.max(0, 16 - (currTime - lastTime));
        var id = window.setTimeout(function() { callback(currTime + timeToCall); }, 
          timeToCall);
        lastTime = currTime + timeToCall;
        return id;
      };
    if (!window.cancelAnimationFrame)
      window.cancelAnimationFrame = function(id) {
        clearTimeout(id);
      };
  }());

  var canvas,
      currentProgress,
      showing,
      progressTimerId = null,
      fadeTimerId = null,
      delayTimerId = null,
      addEvent = function (elem, type, handler) {
          if (elem.addEventListener) elem.addEventListener(type, handler, false)
          else if (elem.attachEvent) elem.attachEvent('on' + type, handler)
          else elem['on' + type] = handler
      },
      options = {
          autoRun      : true,
          barThickness : 3,
          barColors    : {
              0        : 'rgba(26,  188, 156, .9)',
              '.25'    : 'rgba(52,  152, 219, .9)',
              '.50'    : 'rgba(241, 196, 15,  .9)',
              '.75'    : 'rgba(230, 126, 34,  .9)',
              '1.0'    : 'rgba(211, 84,  0,   .9)'
          },
          shadowBlur   : 10,
          shadowColor  : 'rgba(0,   0,   0,   .6)',
          className    : null
      },
      repaint = function () {
          canvas.width = window.innerWidth
          canvas.height = options.barThickness * 5 // space for shadow
          
          var ctx = canvas.getContext('2d')
          ctx.clearRect(0, 0, canvas.width, canvas.height)
          
          if (currentProgress == 0) return
          
          // Shadow
          ctx.shadowBlur = options.shadowBlur
          ctx.shadowColor = options.shadowColor
          
          var lineGradient = ctx.createLinearGradient(0, 0, canvas.width, 0)
          for (var stop in options.barColors)
              lineGradient.addColorStop(stop, options.barColors[stop])
          ctx.fillStyle = lineGradient
          ctx.fillRect(0, 0, canvas.width * Math.min(1, currentProgress), options.barThickness)
      },
      createCanvas = function () {
          canvas = document.createElement('canvas')
          var style = canvas.style
          style.position = 'fixed'
          style.top = style.left = style.right = style.margin = style.padding = style.border = '0'
          style.zIndex = '100001'
          style.display = 'none'
          if (options.className) canvas.className = options.className
          document.body.appendChild(canvas)
          addEvent(window, 'resize', repaint)
      },
      topbar = {
          config: function (opts) {
              for (var key in opts)
                  if (options.hasOwnProperty(key))
                      options[key] = opts[key]
          },
          show: function (delay) {
              var fromStart = true

              if (delay !== undefined && delay !== null) {
                delay = Math.max(parseFloat(delay), 0);
                fromStart = false;
              } else {
                delay = 0;
              }

              if (showing) return
              if (delayTimerId !== null) return

              if (delay > 0) {
                delayTimerId = setTimeout(() => topbar.show(), delay);
                return;
              }

              showing = true
              if (fadeTimerId !== null) 
                  window.cancelAnimationFrame(fadeTimerId)
              if (!canvas) createCanvas()
              canvas.style.opacity = 1
              canvas.style.display = 'block'
              topbar.progress(fromStart ? 0 : currentProgress || 0)
              if (options.autoRun) {
                  (function loop() {
                      progressTimerId = window.requestAnimationFrame(loop)
                      topbar.progress('+' + Math.random() * 0.05 * (1 - Math.sqrt(currentProgress)))
                  })()
              }
          },
          progress: function (to) {
              if (typeof to === 'undefined') return currentProgress
              if (typeof to === 'string') {
                  to = (to.charAt(0) === '+' || to.charAt(0) === '-' ? currentProgress : 0) + parseFloat(to)
              }
              currentProgress = Math.max(0, Math.min(1, to))
              repaint()
              return currentProgress
          },
          hide: function () {
              clearTimeout(delayTimerId);
              delayTimerId = null;
              if (!showing) return
              showing = false
              if (progressTimerId != null) {
                  window.cancelAnimationFrame(progressTimerId)
                  progressTimerId = null
              }
              (function loop() {
                  if (topbar.progress('+.1') >= 1) {
                      canvas.style.opacity -= .05
                      if (canvas.style.opacity <= .05) {
                          canvas.style.display = 'none'
                          fadeTimerId = null
                          return
                      }
                  }
                  fadeTimerId = window.requestAnimationFrame(loop)
              })()
          }
      }

  if (typeof module === 'object' && typeof module.exports === 'object') {
      module.exports = topbar
  } else if (typeof define === 'function' && define.amd) {
      define(function() { return topbar })
  } else {
      this.topbar = topbar
  }

}).call(this, window, document)