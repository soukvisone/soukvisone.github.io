/* ==========================================================================
   site.js — ธีม / เมนูมือถือ / ปุ่ม copy / ค้นหา
   ไม่มี dependency ภายนอก
   ========================================================================== */
(function () {
  "use strict";

  // ---------- 1) ธีมสว่าง/มืด ----------
  var KEY = "notes-theme";
  function applyTheme(t) {
    document.documentElement.setAttribute("data-theme", t);
    try { localStorage.setItem(KEY, t); } catch (e) {}
    var btn = document.getElementById("theme-btn");
    if (btn) btn.textContent = t === "dark" ? "☀️" : "🌙";
  }
  var saved = null;
  try { saved = localStorage.getItem(KEY); } catch (e) {}
  if (!saved) {
    saved = window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
  }
  applyTheme(saved);

  document.addEventListener("click", function (ev) {
    var t = ev.target.closest("#theme-btn");
    if (t) {
      var cur = document.documentElement.getAttribute("data-theme") === "dark" ? "light" : "dark";
      applyTheme(cur);
    }
    var m = ev.target.closest("#menu-btn");
    if (m) document.body.classList.toggle("nav-open");
  });

  // ---------- 2) ปุ่มคัดลอกโค้ด ----------
  document.querySelectorAll("pre").forEach(function (pre) {
    var btn = document.createElement("button");
    btn.className = "copy";
    btn.type = "button";
    btn.textContent = "copy";
    btn.addEventListener("click", function () {
      var code = pre.querySelector("code");
      var text = code ? code.innerText : pre.innerText;
      var done = function () {
        btn.textContent = "copied ✓";
        btn.classList.add("done");
        setTimeout(function () { btn.textContent = "copy"; btn.classList.remove("done"); }, 1400);
      };
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(done, function () { fallback(text, done); });
      } else {
        fallback(text, done);
      }
    });
    pre.appendChild(btn);
  });

  function fallback(text, done) {
    var ta = document.createElement("textarea");
    ta.value = text;
    ta.style.position = "fixed";
    ta.style.opacity = "0";
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand("copy"); done(); } catch (e) {}
    document.body.removeChild(ta);
  }

  // ---------- 3) ค้นหาในหน้าแรก ----------
  var input = document.getElementById("search");
  if (input) {
    var cards = Array.prototype.slice.call(document.querySelectorAll("[data-search]"));
    var blocks = Array.prototype.slice.call(document.querySelectorAll(".cat-block"));
    var empty = document.getElementById("no-result");

    var run = function () {
      var q = input.value.trim().toLowerCase();
      var visible = 0;
      cards.forEach(function (c) {
        var hay = (c.getAttribute("data-search") || "").toLowerCase();
        var ok = !q || hay.indexOf(q) !== -1;
        c.classList.toggle("hidden", !ok);
        if (ok) visible++;
      });
      blocks.forEach(function (b) {
        var any = b.querySelectorAll("[data-search]:not(.hidden)").length;
        b.classList.toggle("hidden", any === 0);
      });
      if (empty) empty.classList.toggle("hidden", visible !== 0);
    };

    input.addEventListener("input", run);

    // กด "/" เพื่อโฟกัสช่องค้นหา
    document.addEventListener("keydown", function (e) {
      if (e.key === "/" && document.activeElement !== input) {
        e.preventDefault();
        input.focus();
      }
      if (e.key === "Escape") input.blur();
    });

    // รองรับ ?q= จากหน้าอื่น
    var m = new URLSearchParams(window.location.search).get("q");
    if (m) { input.value = m; run(); }
  }

  // ---------- 4) ไฮไลต์เมนูปัจจุบัน ----------
  var here = location.pathname.split("/").pop() || "index.html";
  document.querySelectorAll(".nav a").forEach(function (a) {
    var href = a.getAttribute("href") || "";
    if (href.split("/").pop() === here) a.classList.add("active");
  });

  // ---------- 5) ปิดเมนูเมื่อคลิกลิงก์ (มือถือ) ----------
  document.querySelectorAll(".nav a").forEach(function (a) {
    a.addEventListener("click", function () { document.body.classList.remove("nav-open"); });
  });
})();
