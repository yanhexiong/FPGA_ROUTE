(() => {
  "use strict";

  const R = window.ROUTE;
  const STAGES = R.stages;
  const BRANCH = R.branch;
  const ALL = [...STAGES, BRANCH];
  const SVGNS = "http://www.w3.org/2000/svg";
  const LS_KEY = "fpga-route-state";
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  let state = { checks: {}, contract: {}, notes: {}, general: "" };
  let serverOK = false;

  // ---------- helpers ----------
  const $ = (sel, root = document) => root.querySelector(sel);
  const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const taskKey = (s, i) => `${s.id}-${i}`;
  const code = (s) => (s.branch ? "支线" : `S${STAGES.indexOf(s)}`);
  const stageLabel = (s) => (s.branch ? "可选支线" : `阶段 ${STAGES.indexOf(s)}`);
  const layerText = (s) => s.layers.join(" ");

  const sum = (arr) => arr.reduce((a, b) => a + b, 0);
  // 按勾选比例估算已完成的小时数
  function doneHours(s) {
    const p = progress(s);
    return (s.hours * p.done) / p.total;
  }
  function progress(s) {
    const done = s.tasks.filter((_, i) => state.checks[taskKey(s, i)]).length;
    return { done, total: s.tasks.length };
  }
  function el(tag, attrs = {}, parent) {
    const n = document.createElementNS(SVGNS, tag);
    for (const [k, v] of Object.entries(attrs)) n.setAttribute(k, v);
    if (parent) parent.appendChild(n);
    return n;
  }

  // ---------- route map ----------
  function mapLayout(mode) {
    if (mode === "wide") {
      const bw = 196, bh = 112, xs = [40, 272, 504, 736, 968];
      const topY = 60, botY = 304;
      const blocks = STAGES.map((_, i) => ({
        x: i < 5 ? xs[i] : xs[9 - i],
        y: i < 5 ? topY : botY,
        w: bw, h: bh,
      }));
      // 支线挂在 S8 下方，用虚线接出
      const s8 = blocks[8];
      const branch = { x: s8.x, y: botY + bh + 60, w: bw, h: bh };
      return {
        mode, W: 1204, H: branch.y + bh + 28, blocks, branch, branchFrom: 8,
        boundaryY: (topY + bh + botY) / 2,
        labels: [{ x: 40, y: 38, cls: "sim", t: "无板期：在电脑上仿真" }, { x: 40, y: 284, cls: "board", t: "有板期：上板运行" }],
      };
    }
    const bw = 300, bh = 92, x = 30, gap = 34, cut = 90;
    const blocks = STAGES.map((_, i) => ({ x, y: 52 + i * (bh + gap) + (i >= 5 ? cut : 0), w: bw, h: bh }));
    const b4 = blocks[4], b5 = blocks[5];
    const branch = { x, y: blocks[9].y + bh + 64, w: bw, h: bh };
    return {
      mode, W: 360, H: branch.y + bh + 30, blocks, branch, branchFrom: 9,
      boundaryY: (b4.y + b4.h + b5.y) / 2,
      labels: [{ x: 30, y: 32, cls: "sim", t: "无板期：在电脑上仿真" }, { x: 30, y: b5.y - 16, cls: "board", t: "有板期：上板运行" }],
    };
  }

  // 标题过长时按比例缩小字号，保证不溢出模块
  function fitText(t, maxW) {
    const w = t.getComputedTextLength();
    if (w > maxW) t.style.fontSize = (17 * maxW / w).toFixed(1) + "px";
  }

  // Manhattan segment between consecutive blocks: they always share a row or a column.
  function wireBetween(a, b) {
    const acx = a.x + a.w / 2, acy = a.y + a.h / 2, bcx = b.x + b.w / 2, bcy = b.y + b.h / 2;
    if (Math.abs(acy - bcy) < 1) {
      return bcx > acx ? [a.x + a.w, acy, b.x, bcy] : [a.x, acy, b.x + b.w, bcy];
    }
    return bcy > acy ? [acx, a.y + a.h, bcx, b.y] : [acx, a.y, bcx, b.y + b.h];
  }

  function drawFabric(svg, L) {
    const defs = el("defs", {}, svg);
    // 7 列 CLB + 1 列 BRAM + 1 列 DSP，近似真实 FPGA 的列式布局
    const pat = el("pattern", { id: "fabric", width: 108, height: 60, patternUnits: "userSpaceOnUse" }, defs);
    for (let c = 0; c < 9; c++) {
      const px = c * 12 + 2;
      if (c === 7) { el("rect", { x: px, y: 2, width: 8, height: 56, rx: 1, class: "fab-bram" }, pat); continue; }
      if (c === 8) {
        el("rect", { x: px, y: 2, width: 8, height: 26, rx: 1, class: "fab-dsp" }, pat);
        el("rect", { x: px, y: 32, width: 8, height: 26, rx: 1, class: "fab-dsp" }, pat);
        continue;
      }
      for (let r = 0; r < 5; r++) el("rect", { x: px, y: r * 12 + 2, width: 8, height: 8, rx: 1, class: "fab-clb" }, pat);
    }
    el("rect", { x: 0, y: 0, width: L.W, height: L.H, fill: "url(#fabric)", opacity: 0.5 }, svg);
    el("rect", { x: 0, y: 0, width: L.W, height: L.boundaryY, class: "domain-sim" }, svg);
    el("rect", { x: 0, y: L.boundaryY, width: L.W, height: L.H - L.boundaryY, class: "domain-board" }, svg);
    el("line", { x1: 0, y1: L.boundaryY, x2: L.W, y2: L.boundaryY, class: "boundary" }, svg);
    for (const lb of L.labels) {
      const t = el("text", { x: lb.x, y: lb.y, class: `domain-label ${lb.cls}` }, svg);
      t.textContent = lb.t;
    }
  }

  function renderMap() {
    const svg = $("#route-map");
    const mode = window.innerWidth >= 760 ? "wide" : "narrow";
    const L = mapLayout(mode);
    const title = svg.querySelector("title");
    svg.innerHTML = "";
    svg.appendChild(title);
    svg.setAttribute("viewBox", `0 0 ${L.W} ${L.H}`);
    drawFabric(svg, L);

    // signal pulse runs through block centres, underneath the blocks
    const pts = L.blocks.map((b) => [b.x + b.w / 2, b.y + b.h / 2]);
    const pulse = el("path", { d: "M" + pts.map((p) => p.join(",")).join(" L"), class: "pulse" }, svg);

    // wires
    const wires = el("g", {}, svg);
    for (let i = 0; i < L.blocks.length - 1; i++) {
      const [x1, y1, x2, y2] = wireBetween(L.blocks[i], L.blocks[i + 1]);
      const p = progress(STAGES[i]);
      const lit = p.done === p.total ? " lit" : "";
      el("line", { x1, y1, x2, y2, class: "wire" + lit }, wires);
      el("circle", { cx: x1, cy: y1, r: 4, class: "via" + lit }, wires);
      el("circle", { cx: x2, cy: y2, r: 4, class: "via" + lit }, wires);

      // 板子到货 = 跨时钟域：在跨越边界的那根线上画一个两级同步器
      if (i === 4) {
        const cx = x1, by = L.boundaryY;
        el("rect", { x: cx - 9, y: by - 21, width: 18, height: 16, rx: 2, class: "sync-ff" }, wires);
        el("rect", { x: cx - 9, y: by + 5, width: 18, height: 16, rx: 2, class: "sync-ff" }, wires);
        const tx = mode === "wide" ? cx - 22 : cx + 22, anchor = mode === "wide" ? "end" : "start";
        const t1 = el("text", { x: tx, y: by - 3, "text-anchor": anchor, class: "sync-label" }, wires);
        t1.textContent = "板子到货";
        const t2 = el("text", { x: tx, y: by + 15, "text-anchor": anchor, class: "sync-sub" }, wires);
        t2.textContent = "跨入新的时钟域";
      }
    }

    // 支线：虚线接出
    {
      const from = L.blocks[L.branchFrom], b = L.branch;
      const cx = from.x + from.w / 2;
      const p = progress(BRANCH);
      el("line", { x1: cx, y1: from.y + from.h, x2: cx, y2: b.y, class: "wire branch-wire" + (p.done === p.total ? " lit" : "") }, wires);
      const lt = el("text", { x: cx + 14, y: (from.y + from.h + b.y) / 2 + 5, class: "branch-label" }, wires);
      lt.textContent = "可选支线，穿插在 S8–S9 期间";
    }

    // blocks
    STAGES.forEach((s, i) => drawBlock(svg, s, L.blocks[i], mode));
    drawBlock(svg, BRANCH, L.branch, mode);

    return pulse;
  }

  function drawBlock(svg, s, b, mode) {
    const p = progress(s);
    const g = el("g", {
      class: `map-block ${s.domain}${p.done === p.total ? " done" : ""}`,
      tabindex: 0, role: "link",
      "aria-label": `${stageLabel(s)}：${s.title}，层次：${s.layers.join("、")}，已完成 ${p.done}/${p.total}`,
    }, svg);
    el("rect", { x: b.x, y: b.y, width: b.w, height: b.h, rx: 4, class: "blk" }, g);
    const pad = 16, narrow = mode === "narrow";
    const n = el("text", { x: b.x + pad, y: b.y + (narrow ? 24 : 26), class: "num" }, g);
    n.textContent = code(s);
    // 层次标签：宽屏放右上角，窄屏放在 meta 行右侧
    const lt = el("text", { x: b.x + b.w - pad, y: b.y + (narrow ? 54 : 26), "text-anchor": "end", class: "lyr" }, g);
    lt.textContent = layerText(s);
    const tx = b.x + pad + (narrow ? (s.branch ? 40 : 32) : 0);
    const t = el("text", { x: tx, y: b.y + (narrow ? 24 : 56), class: "ttl" }, g);
    t.textContent = s.short;
    fitText(t, b.x + b.w - pad - tx);
    const m = el("text", { x: b.x + pad, y: b.y + (narrow ? 54 : 82), class: "meta" }, g);
    m.textContent = `约 ${s.hours} 小时　${p.done}/${p.total}`;
    const bwid = b.w - pad * 2;
    el("rect", { x: b.x + pad, y: b.y + b.h - 16, width: bwid, height: 3, rx: 1.5, class: "bar-bg" }, g);
    el("rect", { x: b.x + pad, y: b.y + b.h - 16, width: (bwid * p.done) / p.total, height: 3, rx: 1.5, class: "bar" }, g);
    const go = () => document.getElementById(s.id).scrollIntoView({ block: "start" });
    g.addEventListener("click", go);
    g.addEventListener("keydown", (e) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); go(); } });
  }

  function playPulse(pulse) {
    if (reduceMotion || !pulse.animate) return;
    const len = pulse.getTotalLength();
    pulse.style.opacity = 1;
    pulse.style.strokeDasharray = `56 ${len + 56}`;
    const a = pulse.animate(
      [{ strokeDashoffset: 56 }, { strokeDashoffset: -len }],
      { duration: 3400, easing: "cubic-bezier(.45,.05,.35,1)", delay: 300, fill: "both" }
    );
    a.onfinish = () => { pulse.style.opacity = 0; };
  }

  // ---------- planner ----------
  function renderPlanner() {
    const total = sum(STAGES.map((s) => s.hours));
    const noBoard = sum(STAGES.slice(0, 5).map((s) => s.hours));
    const done = Math.round(sum(ALL.map(doneHours)));
    $("#plan-out").innerHTML =
      `整条主线预计约 <strong>${total} 小时</strong>。其中前五个阶段不需要板子，约 ${noBoard} 小时；` +
      `上板之后的五个阶段约 ${total - noBoard} 小时。可选的 CUDA 支线另需约 ${BRANCH.hours} 小时，不计入主线。` +
      `按已勾选的任务估算，目前完成约 <strong>${done} 小时</strong>。`;
    $("#hour-bar").innerHTML = STAGES.map((s, i) => {
      const pct = Math.round((doneHours(s) / s.hours) * 100);
      return `<a class="hb-seg ${s.domain}" href="#${s.id}" style="flex-grow:${s.hours}" title="S${i} ${esc(s.short)}：约 ${s.hours} 小时">
        <span class="hb-fill" style="width:${pct}%"></span>
        <span class="hb-txt"><b>S${i}</b> ${s.hours}h</span></a>`;
    }).join("");
  }

  // ---------- stages ----------
  function concept(c) {
    const i = c.indexOf("：");
    return i > 0 && i < 24 ? `<b>${esc(c.slice(0, i))}</b>：${esc(c.slice(i + 1))}` : esc(c);
  }

  function envChip(s, t) {
    if (t.gpu) return `<span class="chip gpu">需 GPU</span>`;
    if (t.board) return `<span class="chip board">需板</span>`;
    return `<span class="chip sim">${s.branch ? "只需电脑" : "仿真"}</span>`;
  }

  function renderStages() {
    const main = $("#stages");
    main.innerHTML = ALL.map((s) => {
      const tasks = s.tasks.map((t, i) => {
        const k = taskKey(s, i);
        return `<li><label>
          <input type="checkbox" data-task="${k}" ${state.checks[k] ? "checked" : ""}>
          <span>${esc(t.t)}</span>
          <span class="chips">${t.frag ? `<span class="chip frag">1 小时可做</span>` : ""}${envChip(s, t)}</span>
        </label></li>`;
      }).join("");
      const res = s.resources.map((r) =>
        `<li>${r.url ? `<a href="${esc(r.url)}" target="_blank" rel="noopener">${esc(r.name)}</a>` : esc(r.name)}${r.zh ? `<span class="zh-tag">中文</span>` : ""}${r.note ? `<span class="res-note">${esc(r.note)}</span>` : ""}</li>`
      ).join("");
      const pits = s.pitfalls.map((p) => `<li>${esc(p)}</li>`).join("");
      const qs = s.questions.length ? `<ul>${s.questions.map((q) => `<li>${esc(q)}</li>`).join("")}</ul>` : "";
      const simCount = s.tasks.filter((t) => !t.board).length;
      const domainText = s.branch ? `需要 NVIDIA GPU，不需要 FPGA 板；${s.when}`
        : s.domain === "sim" ? "全部可在仿真中完成" : `需要板子，其中 ${simCount} 项任务可先仿真`;
      const tags = s.layers.map((l) => `<span class="layer-tag">${esc(l)}</span>`).join("");
      return `<section class="stage ${s.domain}" id="${s.id}" aria-labelledby="${s.id}-h">
        <div class="stage-head">
          ${s.branch
            ? `<span class="stage-n">${stageLabel(s)}</span><h2 id="${s.id}-h">${esc(s.title)}</h2>`
            : `<h2 id="${s.id}-h"><span class="stage-n">${stageLabel(s)}<span class="sep">：</span></span>${esc(s.title)}</h2>`}
        </div>
        <div class="stage-meta">
          <span>约 ${s.hours} 小时</span>
          <span>${domainText}</span>
          <a class="layers" href="#stack" title="在 AI 系统栈中的层次">${tags}</a>
        </div>
        <p class="stage-goal">${esc(s.goal)}</p>
        <p class="stage-why">${esc(s.why)}</p>

        <p class="h4">要掌握的概念</p>
        <ul class="concepts">${s.concepts.map((c) => `<li>${concept(c)}</li>`).join("")}</ul>

        <p class="h4">动手任务</p>
        <ul class="tasks">${tasks}</ul>

        <div class="deliverable"><b>验收标准</b>${esc(s.deliverable)}</div>

        <div class="stage-lower">
          <div><p class="h4">学习资料</p><ul>${res}</ul></div>
          <div><p class="h4">容易踩的坑</p><ul>${pits}</ul></div>
          <div class="discuss">
            <p class="h4">待讨论</p>
            ${qs}
            <textarea class="notes" data-note="${s.id}" rows="3" aria-label="${stageLabel(s)}讨论笔记"
              placeholder="写下你的回答、疑问或想调整的地方"></textarea>
            <div class="print-notes" data-print-note="${s.id}"></div>
          </div>
        </div>
      </section>`;
    }).join("");

    main.querySelectorAll("textarea[data-note]").forEach((t) => { t.value = state.notes[t.dataset.note] || ""; });
    syncPrintNotes();
  }

  function renderToc() {
    $("#toc-list").innerHTML = STAGES.map((s, i) => {
      const p = progress(s);
      const cut = i === 5 ? `<li class="toc-cut">板子到货</li>` : "";
      return `${cut}<li><a href="#${s.id}">
        <span class="toc-n ${s.domain}">S${i}</span>
        <span class="toc-title">${esc(s.short)}</span>
        <span class="toc-count${p.done === p.total ? " full" : ""}">${p.done}/${p.total}</span>
      </a></li>`;
    }).join("") + (() => {
      const p = progress(BRANCH);
      return `<li class="toc-cut">可选支线</li><li><a href="#${BRANCH.id}">
        <span class="toc-n branch">支线</span>
        <span class="toc-title">${esc(BRANCH.short)}</span>
        <span class="toc-count${p.done === p.total ? " full" : ""}">${p.done}/${p.total}</span>
      </a></li>`;
    })();
  }

  function renderBoards() {
    $("#board-rows").innerHTML = R.boards.map((b) => `<tr class="${b.pick ? "pick" : ""}">
      <td>${esc(b.name)}${b.pick ? `<span class="pick-tag">推荐先买</span>` : ""}</td>
      <td>${esc(b.chip)}</td><td>${esc(b.spec)}</td><td>${esc(b.price)}</td>
      <td>${esc(b.covers)}</td><td>${esc(b.note)}</td></tr>`).join("");
  }

  function renderSkills() {
    $("#skill-list").innerHTML = R.sideSkills.map((k) => `<li>
      <span class="verdict ${k.verdict}">${esc(k.label)}</span>
      <div><p class="h3">${esc(k.name)}</p><p>${esc(k.body)}</p></div></li>`).join("");
  }

  function renderStack() {
    const coverText = { full: "覆盖", part: "部分覆盖", none: "不涉及" };
    $("#stack-list").innerHTML = R.stack.map((l) => {
      const hits = ALL.filter((s) => s.layers.includes(l.key));
      const links = hits.map((s) => `<a href="#${s.id}" class="stack-stage${s.layers[0] === l.key ? " main" : ""}">${s.branch ? "" : code(s) + " "}${esc(s.short)}</a>`).join("");
      return `<li class="stack-row ${l.cover}">
        <div class="stack-name"><p class="h3">${esc(l.name)}</p><span class="stack-cover">${coverText[l.cover]}</span></div>
        <div class="stack-body">
          <p>${esc(l.note)}</p>
          <p class="stack-gpu">GPU 世界的对应：${esc(l.gpu)}</p>
          ${links ? `<div class="stack-stages">${links}</div>` : ""}
        </div>
      </li>`;
    }).join("");
  }

  function renderContract() {
    $("#contract-list").innerHTML = R.contract.map((c) => `<li><label>
      <input type="checkbox" data-contract="${c.id}" ${state.contract[c.id] ? "checked" : ""}>
      <span class="ct"><b>${esc(c.t)}</b><span class="ct-def">默认：${esc(c.def)}</span>${c.try ? `<span class="ct-try">之后可试：${esc(c.try)}</span>` : ""}</span>
      </label></li>`).join("");
  }

  function refreshProgress() {
    renderMap();
    renderToc();
    renderPlanner();
  }

  // 打印 / 导出 PDF 时 textarea 显示不全，用纯文本镜像代替
  function syncPrintNotes() {
    document.querySelectorAll("[data-print-note]").forEach((d) => {
      const id = d.dataset.printNote;
      d.textContent = (id === "general" ? state.general : state.notes[id]) || "";
    });
  }

  // ---------- persistence ----------
  function toMarkdown() {
    const now = new Date();
    const lines = [
      "# FPGA 部署 AI 学习路线：讨论记录",
      "",
      `更新时间：${now.toLocaleString("zh-CN")}　主线预计 ${sum(STAGES.map((s) => s.hours))} 小时，已完成约 ${Math.round(sum(ALL.map(doneHours)))} 小时`,
      "",
    ];
    if (state.general.trim()) lines.push("## 总体讨论", "", state.general.trim(), "");
    STAGES.forEach((s, si) => {
      const p = progress(s);
      lines.push(`## S${si} ${s.title}（${p.done}/${p.total}，约 ${s.hours} 小时）　层次：${s.layers.join("、")}`, "");
      s.tasks.forEach((t, i) => lines.push(`- [${state.checks[taskKey(s, i)] ? "x" : " "}] ${t.t}${t.board ? "（需板）" : ""}${t.frag ? "（1 小时可做）" : ""}`));
      const note = (state.notes[s.id] || "").trim();
      if (note) lines.push("", "**笔记：**", "", note);
      lines.push("");
    });
    {
      const p = progress(BRANCH);
      lines.push(`## 可选支线：${BRANCH.title.replace("可选支线：", "")}（${p.done}/${p.total}，约 ${BRANCH.hours} 小时）`, "");
      BRANCH.tasks.forEach((t, i) => lines.push(`- [${state.checks[taskKey(BRANCH, i)] ? "x" : " "}] ${t.t}${t.gpu ? "（需 GPU）" : ""}${t.frag ? "（1 小时可做）" : ""}`));
      const note = (state.notes[BRANCH.id] || "").trim();
      if (note) lines.push("", "**笔记：**", "", note);
      lines.push("");
    }
    lines.push("## 量化与数据格式约定", "");
    R.contract.forEach((c) => lines.push(`- [${state.contract[c.id] ? "x" : " "}] ${c.t}：${c.def}${c.try ? `（之后可试：${c.try}）` : ""}`));
    lines.push("");
    return lines.join("\n");
  }

  function setStatus(text, warn) {
    const s = $("#save-status");
    s.textContent = text;
    s.classList.toggle("warn", !!warn);
  }

  let saveTimer = null;
  function save() {
    try { localStorage.setItem(LS_KEY, JSON.stringify(state)); } catch (_) { /* 浏览器存储不可用时忽略 */ }
    clearTimeout(saveTimer);
    saveTimer = setTimeout(async () => {
      try {
        const r = await fetch("api/state", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ state, markdown: toMarkdown() }),
        });
        if (!r.ok) throw new Error(r.status);
        serverOK = true;
        const t = new Date().toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit", second: "2-digit" });
        setStatus(`已保存到 notes/ 目录 ${t}`);
      } catch (_) {
        serverOK = false;
        setStatus("没连上本地服务，改动只存在浏览器里。请用 ./start.sh 启动。", true);
      }
    }, 500);
  }

  async function load() {
    let loaded = null;
    try {
      const r = await fetch("api/state", { cache: "no-store" });
      if (r.ok) { loaded = await r.json(); serverOK = true; }
    } catch (_) { /* 直接双击打开 html 时没有服务端 */ }
    if (!loaded || !Object.keys(loaded).length) {
      try { loaded = JSON.parse(localStorage.getItem(LS_KEY) || "null"); } catch (_) { loaded = null; }
    }
    if (loaded) state = { ...state, ...loaded };
    delete state.hours; // 旧版本按每周小时数换算，已改为按阶段小时数
    setStatus(serverOK ? "勾选和笔记会自动保存到 notes/ 目录" : "没连上本地服务，改动只存在浏览器里。请用 ./start.sh 启动。", !serverOK);
  }

  // ---------- events ----------
  function bind() {
    document.addEventListener("change", (e) => {
      const t = e.target;
      if (t.dataset.task) { state.checks[t.dataset.task] = t.checked; refreshProgress(); save(); }
      else if (t.dataset.contract) { state.contract[t.dataset.contract] = t.checked; save(); }
    });
    document.addEventListener("input", (e) => {
      const t = e.target;
      if (t.dataset.note) { state.notes[t.dataset.note] = t.value; syncPrintNotes(); save(); }
      else if (t.id === "general-notes") { state.general = t.value; syncPrintNotes(); save(); }
    });
    let lastMode = window.innerWidth >= 760;
    window.addEventListener("resize", () => {
      const m = window.innerWidth >= 760;
      if (m !== lastMode) { lastMode = m; renderMap(); }
    });
  }

  async function init() {
    await load();
    renderPlanner();
    renderStages();
    renderToc();
    renderBoards();
    renderSkills();
    renderStack();
    renderContract();
    $("#general-notes").value = state.general || "";
    syncPrintNotes();
    const pulse = renderMap();
    bind();
    playPulse(pulse);
    // 内容是异步渲染的，浏览器自带的锚点跳转发生得太早，这里补一次
    if (location.hash) {
      const target = document.getElementById(decodeURIComponent(location.hash.slice(1)));
      if (target) target.scrollIntoView({ block: "start", behavior: "instant" });
    }
  }

  init();
})();
