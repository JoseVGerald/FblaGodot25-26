/* ===========================================================================
   My Little Buddy — NEW UI prototype
   Faithful HTML recreation of the /new ui/ tileset menus, populated with the
   real words & assets pulled from the game's GDScript, plus the missing
   button feedback: pixel-press + hover highlight + click sound.
   =========================================================================== */
(() => {
  "use strict";

  /* ----------------------------------------------------------- sound ------ */
  let AC = null, soundOn = true;
  function clickSound(kind) {
    if (!soundOn) return;
    try {
      AC = AC || new (window.AudioContext || window.webkitAudioContext)();
      const t = AC.currentTime;
      const o = AC.createOscillator(), g = AC.createGain();
      o.type = "square";
      const f = kind === "down" ? 660 : 880;
      o.frequency.setValueAtTime(f, t);
      o.frequency.exponentialRampToValueAtTime(f * 0.6, t + 0.06);
      g.gain.setValueAtTime(0.06, t);
      g.gain.exponentialRampToValueAtTime(0.0001, t + 0.08);
      o.connect(g); g.connect(AC.destination);
      o.start(t); o.stop(t + 0.09);
    } catch (e) { /* no audio */ }
  }

  /* ------------------------------------------- press behaviour (delegated) - */
  const PRESS_SEL = ".pixel-btn, .row-btn, .x-btn, .dot-x";
  function bindPress(root) {
    root.addEventListener("pointerdown", (e) => {
      const b = e.target.closest(PRESS_SEL);
      if (!b || b.hasAttribute("disabled")) return;
      b.classList.add("pressed");
      clickSound("down");
    });
    const release = (e) => {
      document.querySelectorAll(".pressed").forEach((b) => b.classList.remove("pressed"));
    };
    root.addEventListener("pointerup", release);
    root.addEventListener("pointercancel", release);
    root.addEventListener("pointerleave", release, true);
  }

  /* ------------------------------------------------------------ helpers --- */
  const $ = (sel, r = document) => r.querySelector(sel);
  function toast(msg) {
    let t = $("#toast");
    if (!t) { t = document.createElement("div"); t.id = "toast"; document.body.appendChild(t); }
    t.textContent = msg;
    t.className = "show";
    clearTimeout(t._t);
    t._t = setTimeout(() => (t.className = ""), 1400);
  }
  // corners markup
  const CORNERS = `<span class="corner tl"></span><span class="corner tr"></span><span class="corner bl"></span><span class="corner br"></span>`;

  /* ----------------------------------------------------- dog sprite anim --- */
  const BREEDS = [
    { name: "Golden Retriever", sheet: "assets/dogs/GoldenIdle_sheet.png", frames: 10 },
    { name: "Husky",            sheet: "assets/dogs/HuskyIdle_sheet.png",  frames: 6 },
    { name: "Dalmatian",        sheet: "assets/dogs/GoldenIdle_sheet.png", frames: 10 },
    { name: "Labrador",         sheet: "assets/dogs/GoldenIdle_sheet.png", frames: 10 },
    { name: "Rottweiler",       sheet: "assets/dogs/HuskyIdle_sheet.png",  frames: 6 },
    { name: "Argentino",        sheet: "assets/dogs/GoldenIdle_sheet.png", frames: 10 },
    { name: "Pharaoh Hound",    sheet: "assets/dogs/HuskyIdle_sheet.png",  frames: 6 },
    { name: "Cane Corso",       sheet: "assets/dogs/GoldenIdle_sheet.png", frames: 10 },
  ];
  function animateSprite(node, breed, flip) {
    const FRAME_W = 192; // 64px sheet frame scaled x3
    node.style.backgroundImage = `url("${breed.sheet}")`;
    node.style.transform = flip ? "scaleX(-1)" : "none";
    let f = 0;
    if (node._timer) clearInterval(node._timer);
    node._timer = setInterval(() => {
      node.style.backgroundPosition = `-${f * FRAME_W}px 0`;
      f = (f + 1) % breed.frames;
    }, 110);
  }
  function stopSprites(scope) {
    scope.querySelectorAll(".dog-sprite").forEach((n) => n._timer && clearInterval(n._timer));
  }

  /* =========================================================================
     MENU BUILDERS  — each returns an HTML string for the .frame
     Content (titles, labels, buttons, values) is taken verbatim from the
     game scripts noted in each header comment.
     ========================================================================= */
  const MENUS = {};

  /* 1. OPENING  → MainMenu.gd  (title + Continue / Start / Settings) -------- */
  MENUS.opening = {
    title: "Opening Menu", maps: "MainMenu.tscn · MainMenu.gd", w: 760, h: 560,
    build: () => `
      <div class="frame" style="width:760px;height:560px;display:flex;flex-direction:column;align-items:center;gap:34px;justify-content:flex-start">
        ${CORNERS}
        <div class="plaque" style="width:620px;margin-top:6px"><h2>My Little Buddy</h2></div>
        <div style="display:flex;flex-direction:column;gap:22px;width:360px;margin-top:30px">
          <button class="pixel-btn">Continue Game</button>
          <button class="pixel-btn">Start New Game</button>
          <button class="pixel-btn pixel-btn--gray">Settings</button>
        </div>
      </div>`,
    wire: (s) => {
      s.querySelectorAll(".pixel-btn").forEach((b) =>
        b.addEventListener("click", () => toast(`"${b.textContent}" → ${b.textContent.includes("Continue") ? "load MainGame.tscn" : b.textContent.includes("Start") ? "IntroCutscene.tscn" : "open Settings overlay"}`)));
    },
  };

  /* 2. DOG CHOOSER → PetSelect.gd  (breed cycle ◀ ▶ + Choose) --------------- */
  MENUS.chooser = {
    title: "Dog Chooser", maps: "PetSelect.tscn · PetSelect.gd", w: 820, h: 600,
    build: () => `
      <div class="frame" style="width:820px;height:600px">
        ${CORNERS}
        <div style="position:absolute;inset:26px;background:var(--cream);border:4px solid var(--ink)"></div>
        <div style="position:relative;height:100%;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:8px;padding:20px">
          <div class="menu-title--cream" style="font-size:26px">Choose Your Buddy</div>
          <div style="display:flex;align-items:center;gap:30px;margin-top:4px">
            <button class="pixel-btn pixel-btn--gray" data-cyc="-1" style="font-size:30px;padding:14px 20px">◀</button>
            <div class="dog-stage" style="width:260px;height:200px">
              <div class="dog-sprite" data-dog style="width:192px;height:192px"></div>
            </div>
            <button class="pixel-btn pixel-btn--gray" data-cyc="1" style="font-size:30px;padding:14px 20px">▶</button>
          </div>
          <div data-breed style="font-size:30px;color:var(--maroon-deep);margin-top:4px">Golden Retriever</div>
          <button class="pixel-btn" data-choose style="width:300px;margin-top:18px">Choose This Buddy</button>
        </div>
      </div>`,
    wire: (s) => {
      let i = 0;
      const dog = s.querySelector("[data-dog]"), name = s.querySelector("[data-breed]");
      const render = () => { animateSprite(dog, BREEDS[i], true); name.textContent = BREEDS[i].name; };
      s.querySelectorAll("[data-cyc]").forEach((b) => b.addEventListener("click", () => {
        i = (i + Number(b.dataset.cyc) + BREEDS.length) % BREEDS.length; render();
      }));
      s.querySelector("[data-choose]").addEventListener("click", () => toast(`Saved "${BREEDS[i].name}" → PetName.tscn`));
      render();
    },
  };

  /* 3. PET NAME → PetName.gd  (live dog preview + name field + Continue) ---- */
  MENUS.petname = {
    title: "Pet Name", maps: "PetName.tscn · PetName.gd", w: 820, h: 600,
    build: () => `
      <div class="frame" style="width:820px;height:600px">
        ${CORNERS}
        <div style="position:relative;height:100%;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:22px">
          <div class="menu-title">Name Your Buddy</div>
          <div class="dog-stage" style="width:240px;height:190px;background:var(--cream);border:4px solid var(--ink)">
            <div class="dog-sprite" data-dog style="width:192px;height:192px"></div>
          </div>
          <input class="field" data-name maxlength="14" placeholder="Type a name…" style="width:420px;text-align:center" value="">
          <div class="subtle" data-echo style="color:var(--cream-light)">Letters &amp; spaces only · press Enter</div>
          <button class="pixel-btn" data-go style="width:300px">Continue</button>
        </div>
      </div>`,
    wire: (s) => {
      animateSprite(s.querySelector("[data-dog]"), BREEDS[0], true);
      const inp = s.querySelector("[data-name]"), echo = s.querySelector("[data-echo]"), go = s.querySelector("[data-go]");
      inp.addEventListener("input", () => {
        inp.value = inp.value.replace(/[^A-Za-z ]/g, "");
        echo.textContent = inp.value.trim() ? `Hello, ${inp.value.trim()}!` : "Letters & spaces only · press Enter";
      });
      const submit = () => inp.value.trim() ? toast(`Saved name "${inp.value.trim()}" → CostCustomization.tscn`) : toast("Enter a name first");
      go.addEventListener("click", submit);
      inp.addEventListener("keydown", (e) => e.key === "Enter" && submit());
    },
  };

  /* 4. PET NEEDS → needs_menu.gd  (4 stat bars, X close) -------------------- */
  MENUS.needs = {
    title: "Pet Needs", maps: "needs_menu.gd", w: 640, h: 470,
    build: () => {
      const stats = [
        { nm: "HUNGER", v: 72, c: "var(--hunger)" },
        { nm: "THIRST", v: 54, c: "var(--thirst)" },
        { nm: "ENERGY", v: 88, c: "var(--energy)" },
        { nm: "HEALTH", v: 23, c: "var(--health)" },
      ];
      // 2×2 grid: HUNGER | THIRST  /  ENERGY | HEALTH  — matches the in-game layout
      const cells = stats.map((st) => `
        <div class="stat ${st.v < 30 ? "low" : ""}">
          <div class="top"><span class="nm">${st.nm}${st.v < 30 ? " !" : ""}</span></div>
          <div class="statline"><div class="bar"><i style="width:${st.v}%;background:${st.v < 30 ? "var(--red)" : st.c}"></i></div><span class="vl">${st.v}/100</span></div>
        </div>`).join("");
      return `
      <div style="display:flex;flex-direction:column;gap:12px;width:640px">
        <div class="frame frame--cream frame--tight" style="display:flex;flex-direction:column;gap:18px">
          <div class="title-strip"><div class="menu-title--cream" style="flex:1;text-align:left">Pet Needs</div><button class="x-btn">✕</button></div>
          <div class="uline" style="width:120px"></div>
          <div style="display:grid;grid-template-columns:1fr 1fr;gap:22px 40px;margin-top:4px">${cells}</div>
        </div>
        <div class="hint-box">This tells you the needs of your little buddy. When food or water is low, take them back home to feed them.</div>
      </div>`;
    },
    wire: (s) => closeWire(s),
  };

  /* 5. PET SUPPLIES → supplies_menu.gd  (Food / Water / Medication days) ---- */
  MENUS.supplies = {
    title: "Pet Supplies", maps: "supplies_menu.gd", w: 560, h: 480,
    build: () => `
      <div class="frame frame--cream frame--tight" style="width:560px;height:480px;display:flex;flex-direction:column;gap:18px">
        <div class="title-strip"><div class="menu-title--cream" style="flex:1;text-align:left">Pet Supplies</div><button class="x-btn">✕</button></div>
        <div class="uline" style="width:160px"></div>
        <div style="display:flex;flex-direction:column;margin-top:10px">
          <div class="supply"><img src="assets/icons/DogFood.png" alt=""><span class="lbl">Food</span><span class="days">5 days left</span></div>
          <div class="supply low"><img src="assets/icons/DogWaterBowl.png" alt=""><span class="lbl">Water</span><span class="days" style="color:var(--red)">2 days left</span></div>
          <div class="supply"><img src="assets/icons/DogVitamins.png" alt=""><span class="lbl">Medication</span><span class="days">none prescribed</span></div>
        </div>
        <div style="margin-top:auto;background:#ffd9c2;outline:3px solid var(--red);padding:12px 16px;color:var(--maroon-deep);font-size:16px">! Water running low — visit the Store soon</div>
      </div>`,
    wire: (s) => closeWire(s),
  };

  /* 6. TAXI → taxi_menu.gd  (Home / Store / Vet / Park + cost) -------------- */
  MENUS.taxi = {
    title: "Taxi", maps: "taxi_menu.gd", w: 560, h: 560,
    build: () => {
      const dests = ["Home", "Store", "Vet", "Park"];
      const rows = dests.map((d) => `
        <button class="row-btn"><span class="lead" style="background:var(--orange)"></span>${d}<span class="cost">$12</span></button>`).join("");
      return `
      <div class="frame frame--cream frame--tight" style="width:560px;height:560px;display:flex;flex-direction:column;gap:18px">
        <div class="title-strip"><div class="menu-title--cream" style="flex:1;text-align:left">Call a Taxi</div><button class="x-btn">✕</button></div>
        <div class="uline" style="width:170px"></div>
        <div style="display:flex;flex-direction:column;gap:18px;margin-top:8px">${rows}</div>
      </div>`;
    },
    wire: (s) => {
      closeWire(s);
      s.querySelectorAll(".row-btn").forEach((b) => b.addEventListener("click", () =>
        toast(`Travel to ${b.childNodes[1].textContent.trim()} — spend $12`)));
    },
  };

  /* 7. NOTIFICATIONS → notification_panel.gd  (list + dismiss X + close) ---- */
  MENUS.notifs = {
    title: "Notifications", maps: "notification_panel.gd", w: 720, h: 560,
    build: () => {
      const data = [
        { i: "!", c: "var(--red)",  t: "Warning — Day 6",     m: "Your buddy is getting thirsty", arrow: true },
        { i: "★", c: "var(--gold)", t: "Achievement — Day 5", m: "First Week Survived!",          arrow: true },
        { i: "•", c: "var(--gray-dark)", t: "Event — Day 5",  m: "Weekly allowance received",     arrow: false },
        { i: "!", c: "var(--red)",  t: "Warning — Day 4",     m: "Food supply is low",            arrow: true },
      ];
      const rows = data.map((n) => `
        <div class="notif">
          <span class="nico" style="color:${n.c}">${n.i}</span>
          <div class="ntxt"><div class="nt">${n.t}</div><div class="nm">${n.m}</div></div>
          ${n.arrow ? '<span class="arrow">→</span>' : ""}
          <button class="dot-x">✕</button>
        </div>`).join("");
      return `
      <div class="frame frame--cream frame--tight" style="width:720px;height:560px;display:flex;flex-direction:column;gap:14px">
        <div class="title-strip"><div class="menu-title--cream" style="flex:1;text-align:left">Notifications</div><button class="x-btn">✕</button></div>
        <div class="uline" style="width:100%;height:4px"></div>
        <div class="subtle" data-count style="color:var(--maroon-deep);text-align:center">4 Notifications</div>
        <div style="display:flex;flex-direction:column;gap:10px;overflow:auto">${rows}</div>
      </div>`;
    },
    wire: (s) => {
      closeWire(s);
      const count = s.querySelector("[data-count]");
      const recount = () => { const n = s.querySelectorAll(".notif").length; count.textContent = `${n} Notification${n === 1 ? "" : "s"}`; };
      s.querySelectorAll(".dot-x").forEach((x) => x.addEventListener("click", (e) => {
        e.stopPropagation(); x.closest(".notif").remove(); recount();
      }));
      s.querySelectorAll(".notif").forEach((r) => r.addEventListener("click", () => toast("Open related menu (taxi / finance / achievements)")));
    },
  };

  /* 8. FINANCIAL HUB → finance_menu.gd  (tabs + overview pie + close) ------- */
  MENUS.finance = {
    title: "Financial Hub", maps: "finance_menu.gd", w: 900, h: 640,
    build: () => `
      <div class="frame" style="width:900px;height:640px;display:flex;flex-direction:column;gap:16px">
        ${CORNERS}
        <div style="display:flex;align-items:center;gap:16px">
          <div style="flex:1"><div class="menu-title" style="text-align:left;font-size:30px">Financial Hub</div>
            <div style="color:var(--cream-light);font-size:14px;margin-top:4px">DAY 6 · WEEK 1</div></div>
          <button class="x-btn">✕</button>
        </div>
        <div class="tabs">
          <button class="tab active" data-tab="0">Overview</button>
          <button class="tab" data-tab="1">Budget Planner</button>
          <button class="tab" data-tab="2">Weekly Report</button>
          <button class="tab" data-tab="3">Loans</button>
          <button class="tab" data-tab="4">All-Time History</button>
        </div>
        <div data-pane style="flex:1;background:var(--cream);border:4px solid var(--ink);padding:22px;display:flex;gap:26px;align-items:center"></div>
      </div>`,
    wire: (s) => {
      closeWire(s);
      const pane = s.querySelector("[data-pane]");
      const panes = [
        `<div style="flex:0 0 240px;display:grid;place-items:center">
            <svg width="220" height="220" viewBox="0 0 32 32" style="image-rendering:auto">
              <circle cx="16" cy="16" r="15" fill="none" stroke="#493333" stroke-width="2"/>
              <path d="M16 16 L16 1 A15 15 0 0 1 30.5 19.6 Z" fill="#4caf50"/>
              <path d="M16 16 L30.5 19.6 A15 15 0 0 1 9 29.6 Z" fill="#4a90d9"/>
              <path d="M16 16 L9 29.6 A15 15 0 0 1 16 1 Z" fill="#ffa34d"/>
            </svg>
         </div>
         <div style="flex:1;display:flex;flex-direction:column;gap:14px">
            <div style="font-size:24px;color:var(--green)">Spending Money: $148.50</div>
            <div style="font-size:24px;color:var(--cyan)">Emergency Savings: $60.00</div>
            <div style="display:flex;gap:10px;margin-top:6px">
              <input class="field" placeholder="0.00" style="flex:1;font-size:18px">
              <button class="pixel-btn" style="font-size:16px;padding:10px 16px">Deposit</button>
              <button class="pixel-btn pixel-btn--gray" style="font-size:16px;padding:10px 16px">Withdraw</button>
            </div>
            <div style="display:flex;gap:18px;margin-top:6px;font-size:14px">
              <span style="color:var(--green)">● Food &amp; Water</span>
              <span style="color:var(--blue)">● Vet &amp; Medicine</span>
              <span style="color:var(--orange-dark)">● Travel</span>
            </div>
         </div>`,
        budgetPane(), reportPane(), loansPane(), historyPane(),
      ];
      const show = (i) => { pane.innerHTML = panes[i]; pane.classList.add("fade-in"); setTimeout(()=>pane.classList.remove("fade-in"),250);
        s.querySelectorAll(".tab").forEach((t) => t.classList.toggle("active", Number(t.dataset.tab) === i)); };
      s.querySelectorAll(".tab").forEach((t) => t.addEventListener("click", () => show(Number(t.dataset.tab))));
      show(0);
    },
  };
  function budgetPane() {
    const cards = [["Food & Water", "var(--green)", 64], ["Vet & Medicine", "var(--blue)", 28], ["Travel", "var(--orange-dark)", 81]];
    return `<div style="flex:1;display:flex;flex-direction:column;gap:16px">` + cards.map(([n, c, p]) => `
      <div style="background:#fff;outline:3px solid var(--ink);border-left:8px solid ${c};padding:14px 16px">
        <div style="display:flex;justify-content:space-between;font-size:18px"><span>${n}</span><span style="color:${c}">$${(p / 2).toFixed(2)} limit</span></div>
        <div style="height:16px;background:#00000018;outline:2px solid var(--ink);margin-top:8px;position:relative"><i style="position:absolute;inset:0 auto 0 0;width:${p}%;background:${p > 85 ? "var(--red)" : p > 60 ? "var(--orange)" : c};display:block"></i></div>
        <div style="font-size:13px;color:var(--ink-soft);margin-top:5px">Spent ${p}% of budget</div>
      </div>`).join("") + `</div>`;
  }
  function reportPane() {
    const stat = (l, v, c) => `<div style="text-align:center"><div style="font-size:13px;color:var(--ink-soft)">${l}</div><div style="font-size:22px;color:${c}">${v}</div></div>`;
    return `<div style="flex:1;display:flex;flex-direction:column;gap:18px">
      <div style="display:flex;justify-content:space-around;background:#fff;outline:3px solid var(--ink);padding:16px">
        ${stat("INCOME", "+$80.00", "var(--green)")}${stat("SPENT", "-$54.20", "var(--red)")}${stat("NET", "+$25.80", "var(--green)")}${stat("EMERGENCY", "$0.00", "var(--cyan)")}
      </div>
      <div style="font-size:16px;color:var(--maroon-deep);letter-spacing:1px">CATEGORY BREAKDOWN</div>
      <div style="background:#fff;outline:3px solid var(--ink);padding:14px;font-size:15px;display:flex;flex-direction:column;gap:8px">
        <div style="display:flex;justify-content:space-between"><span style="color:var(--green)">Food</span><span>$28.00</span><span style="color:var(--green)">✓ On track</span></div>
        <div style="display:flex;justify-content:space-between"><span style="color:var(--blue)">Vet</span><span>$14.00</span><span style="color:var(--cyan)">– Unused</span></div>
        <div style="display:flex;justify-content:space-between"><span style="color:var(--orange-dark)">Travel</span><span>$12.20</span><span style="color:var(--orange)">! Near limit</span></div>
      </div></div>`;
  }
  function loansPane() {
    return `<div style="flex:1;display:flex;flex-direction:column;gap:16px">
      <div style="background:#fff;outline:3px solid var(--red);padding:18px">
        <div style="font-size:14px;color:var(--ink-soft)">CREDIT BALANCE</div>
        <div style="font-size:34px;color:var(--green)">$0</div>
        <div style="font-size:14px;color:var(--ink-soft);margin-top:6px">$0 / $500 available · 5% weekly</div>
        <div style="height:16px;background:#4caf5022;outline:2px solid var(--ink);margin-top:10px"></div>
      </div>
      <div style="display:flex;gap:10px;align-items:center">
        <input class="field" placeholder="amount" style="flex:1;font-size:18px">
        <button class="pixel-btn" style="font-size:16px;padding:10px 16px">Borrow</button>
        <button class="pixel-btn pixel-btn--gray" style="font-size:16px;padding:10px 16px">Repay</button>
      </div></div>`;
  }
  function historyPane() {
    const rows = [["Day 6", "Income", "Weekly allowance", "+$80.00", "var(--green)"], ["Day 5", "Food", "Dog food x2", "-$18.00", "var(--red)"], ["Day 4", "Travel", "Taxi Commute", "-$12.00", "var(--red)"], ["Day 3", "Vet", "Checkup", "-$24.20", "var(--red)"]];
    return `<div style="flex:1;display:flex;flex-direction:column;gap:10px">
      <div style="display:flex;justify-content:space-between;font-size:18px"><span style="color:var(--green)">Spending Cash: $148.50</span><span style="color:var(--red)">All-Time Spent: $54.20</span></div>
      <div style="background:#fff;outline:3px solid var(--ink);padding:10px;display:flex;flex-direction:column">
        ${rows.map(([d, c, desc, a, col]) => `<div style="display:flex;gap:12px;font-size:15px;padding:8px 4px;border-bottom:2px solid #00000012"><span style="color:var(--cyan);width:60px">${d}</span><span style="flex:1">${desc}</span><span style="color:${col}">${a}</span></div>`).join("")}
      </div></div>`;
  }

  /* 9. SETTINGS → SettingsMenu.gd  (AUDIO / GAME / DISPLAY / CONTROLS) ------ */
  MENUS.settings = {
    title: "Settings", maps: "SettingsMenu.gd", w: 640, h: 660,
    build: () => `
      <div class="frame frame--cream frame--tight" style="width:640px;height:660px;display:flex;flex-direction:column;gap:14px">
        <div class="title-strip"><div class="menu-title--cream" style="flex:1;text-align:left">Settings</div><button class="x-btn">✕</button></div>
        <div style="overflow:auto;display:flex;flex-direction:column;gap:12px;padding-right:4px">
          <div class="section-label">AUDIO</div>
          <div class="set-row"><span class="ico" style="background:#4a90d955"></span><div class="txt"><div class="name">Music Volume</div></div>
            <div class="slider"><div class="track" data-slider="70"><div class="fill" style="width:70%"></div><div class="grab" style="left:70%"></div></div><div class="pct">70%</div></div></div>
          <div class="set-row"><span class="ico" style="background:#2f7fa855"></span><div class="txt"><div class="name">SFX</div></div>
            <div class="slider"><div class="track" data-slider="85"><div class="fill" style="width:85%"></div><div class="grab" style="left:85%"></div></div><div class="pct">85%</div></div></div>
          <div class="set-row"><span class="ico" style="background:#ffa72655"></span><div class="txt"><div class="name">Mute All Audio</div><div class="sub">Silences music and sound effects</div></div><div class="toggle" data-on="false"><div class="knob"></div></div></div>
          <div class="section-label">GAME</div>
          <div class="set-row"><span class="ico" style="background:#4a90d955"></span><div class="txt"><div class="name">Notifications</div><div class="sub">Show warnings and event popups</div></div><div class="toggle" data-on="true"><div class="knob"></div></div></div>
          <div class="set-row"><span class="ico" style="background:#ffa72655"></span><div class="txt"><div class="name">Inflation Active</div><div class="sub">Prices rise slowly over time</div></div><div class="toggle" data-on="true"><div class="knob"></div></div></div>
          <div class="set-row"><span class="ico" style="background:#2f7fa855"></span><div class="txt"><div class="name">Random Events</div><div class="sub">Occasional surprises and challenges</div></div><div class="toggle" data-on="false"><div class="knob"></div></div></div>
          <div class="section-label">DISPLAY</div>
          <div class="set-row"><span class="ico" style="background:#2f7fa855"></span><div class="txt"><div class="name">Tooltips</div><div class="sub">Show helpful hints on hover</div></div><div class="toggle" data-on="true"><div class="knob"></div></div></div>
          <div class="set-row"><span class="ico" style="background:#4a90d955"></span><div class="txt"><div class="name">Fullscreen</div><div class="sub">Expand the game to fill the screen</div></div><div class="toggle" data-on="false"><div class="knob"></div></div></div>
          <div class="section-label">CONTROLS</div>
          <button class="pixel-btn pixel-btn--gray" style="font-size:18px">Keybinds</button>
        </div>
      </div>`,
    wire: (s) => {
      closeWire(s);
      s.querySelectorAll(".toggle").forEach((t) => t.addEventListener("click", () => {
        t.dataset.on = t.dataset.on === "true" ? "false" : "true"; clickSound("up");
      }));
      s.querySelectorAll("[data-slider]").forEach((tr) => bindSlider(tr));
    },
  };

  /* 10. PAUSE → PauseMenu.gd  (Settings / Help / Achievements / Resume / Quit) */
  MENUS.pause = {
    title: "Pause", maps: "PauseMenu.gd", w: 520, h: 620,
    build: () => {
      const items = [["Settings", "var(--blue)"], ["Help", "var(--cyan)"], ["Achievements", "var(--gold)"], ["Resume", "var(--green)"], ["Quit", "var(--red)"]];
      const rows = items.map(([n, c]) => `<button class="row-btn"><span class="lead" style="background:${c}"></span>${n}</button>`).join("");
      return `
      <div class="frame frame--cream frame--tight" style="width:520px;height:620px;display:flex;flex-direction:column;gap:18px">
        <div class="title-strip"><div class="menu-title--cream" style="flex:1;text-align:left">Paused</div><button class="x-btn">✕</button></div>
        <div class="uline" style="width:120px"></div>
        <div style="display:flex;flex-direction:column;gap:18px;margin-top:6px">${rows}</div>
      </div>`;
    },
    wire: (s) => {
      closeWire(s);
      s.querySelectorAll(".row-btn").forEach((b) => b.addEventListener("click", () => toast(`${b.textContent.trim()} pressed`)));
    },
  };

  /* 11. GAME OVERVIEW → final_stats_screen.gd  (CONGRATS + stats + chart) --- */
  MENUS.overview = {
    title: "Game Overview", maps: "final_stats_screen.gd", w: 940, h: 600,
    build: () => `
      <div class="frame" style="width:940px;height:600px;display:flex;flex-direction:column;gap:16px">
        ${CORNERS}
        <div class="plaque" style="width:100%"><h2 style="color:var(--orange-dark)">CONGRATULATIONS!</h2></div>
        <div style="display:flex;gap:20px;flex:1;min-height:0">
          <div style="flex:1;display:flex;flex-direction:column;gap:10px">
            <div style="color:var(--cream-light);font-size:15px">You bought the house and secured a forever home for Biscuit!</div>
            <div style="background:var(--cream);border:4px solid var(--ink);padding:14px;display:flex;flex-direction:column;gap:9px;font-size:16px">
              <div style="display:flex;justify-content:space-between"><span style="color:var(--ink-soft)">Player Name</span><span>Alex</span></div>
              <div style="display:flex;justify-content:space-between"><span style="color:var(--ink-soft)">Buddy's Name</span><span>Biscuit</span></div>
              <div style="display:flex;justify-content:space-between"><span style="color:var(--ink-soft)">Days Played</span><span>21</span></div>
              <div style="display:flex;justify-content:space-between"><span style="color:var(--ink-soft)">Starting Cash</span><span>$100.00</span></div>
              <div style="display:flex;justify-content:space-between"><span style="color:var(--ink-soft)">Ending Cash</span><span>$148.50</span></div>
              <div style="display:flex;justify-content:space-between"><span style="color:var(--ink-soft)">Ending Savings</span><span>$60.00</span></div>
            </div>
          </div>
          <div style="flex:1;background:var(--pink);border:4px solid var(--ink);padding:14px;display:flex;flex-direction:column">
            <div style="font-size:14px;color:var(--ink)">COMPOUNDED SAVINGS BALANCE</div>
            <svg viewBox="0 0 300 200" style="flex:1;width:100%">
              <polyline fill="none" stroke="#4caf50" stroke-width="3" points="10,180 60,160 110,150 160,110 210,90 260,40 290,20"/>
              ${[ [10,180],[60,160],[110,150],[160,110],[210,90],[260,40],[290,20] ].map(([x,y])=>`<circle cx="${x}" cy="${y}" r="4" fill="#4caf50"/>`).join("")}
              <line x1="10" y1="190" x2="290" y2="190" stroke="#49333366"/>
            </svg>
          </div>
        </div>
        <div style="display:flex;justify-content:center"><button class="pixel-btn" style="width:340px">Return to Main Menu</button></div>
      </div>`,
    wire: (s) => s.querySelector(".pixel-btn").addEventListener("click", () => toast("Reset GameState → MainMenu.tscn")),
  };

  /* 12. CHARACTER CREATOR → CharacterCustomize.gd  (player editor, re-skinned) */
  const CHAR = {
    dirs: ["left", "down", "up", "right"],
    dirLabels: { left: "LEFT", down: "FRONT", up: "BACK", right: "RIGHT" },
    tabs: ["BODY", "HAIR", "ACCESSORIES", "OUTFIT", "EYES"],
    // real cropped sprite options per layer (others are placeholders to match the game grid)
    body: ["body1", "body3"],
    hair: ["hair1", "hair3"],
  };
  function charSpriteURL(kind, dir) { return `assets/char/${kind}_${dir}.png`; }

  MENUS.charcreator = {
    title: "Character Creator", maps: "CharacterCustomize.gd · CharacterAssets.gd", w: 1180, h: 720,
    build: () => {
      const tabStrip = CHAR.tabs.map((t, i) =>
        `<button class="cc-tab ${i === 0 ? "active" : ""}" data-tab="${t}">${t}</button>`).join("");
      const checks = CHAR.tabs.map((t) =>
        `<label class="cc-check"><span class="cc-box" data-vis="${t}" data-on="true"></span>${t}</label>`).join("");
      const mini = CHAR.dirs.map((d) =>
        `<div class="cc-mini ${d === "down" ? "sel" : ""}" data-mini="${d}">
           <div class="cc-mini-layer" data-ml="body" style="background-image:url('${charSpriteURL("body1", d)}')"></div>
           <div class="cc-mini-layer" data-ml="hair" style="background-image:url('${charSpriteURL("hair1", d)}')"></div>
         </div>`).join("");
      return `
      <div class="frame" style="width:1180px;height:720px;display:flex;flex-direction:column;gap:16px;padding:24px">
        ${CORNERS}
        <div class="plaque" style="width:520px;align-self:center;padding:10px 26px"><h2 style="font-size:24px">CHARACTER CREATOR</h2></div>
        <div style="display:flex;gap:24px;flex:1;min-height:0">
          <!-- LEFT: preview + carousel -->
          <div style="flex:0 0 320px;display:flex;flex-direction:column;align-items:center;gap:14px">
            <div class="cc-stage">
              <div class="cc-layer" data-layer="body" data-kind="body1"></div>
              <div class="cc-layer" data-layer="hair" data-kind="hair1"></div>
            </div>
            <div class="cc-mini-row">${mini}</div>
            <div class="cc-carousel">
              <button class="pixel-btn pixel-btn--gray" data-dir="-1" style="font-size:22px;padding:10px 16px">◀</button>
              <div class="cc-dir-label" data-dirlabel>FRONT</div>
              <button class="pixel-btn pixel-btn--gray" data-dir="1" style="font-size:22px;padding:10px 16px">▶</button>
            </div>
          </div>
          <!-- RIGHT: tabs + grid -->
          <div style="flex:1;display:flex;flex-direction:column;gap:12px;min-width:0">
            <div class="cc-tabs">${tabStrip}</div>
            <div class="cc-grid" data-grid></div>
          </div>
        </div>
        <!-- BOTTOM BAR -->
        <div class="cc-bottom">
          <div style="display:flex;gap:12px">
            <button class="pixel-btn pixel-btn--gray" style="font-size:18px;padding:12px 20px">BACK</button>
            <button class="pixel-btn" data-rand style="font-size:18px;padding:12px 20px;background:var(--orange)">RANDOMIZE</button>
          </div>
          <div style="display:flex;align-items:center;gap:12px">
            <span style="font-size:20px;color:var(--ink)">NAME:</span>
            <input class="field" data-ccname maxlength="25" placeholder="Enter Name" style="width:220px;font-size:18px;padding:10px 14px">
          </div>
          <div style="display:flex;align-items:center;gap:14px">
            <div class="cc-checks">${checks}</div>
            <button class="pixel-btn" data-cont style="font-size:18px;padding:12px 20px;background:var(--green);color:#fff" disabled>CONTINUE</button>
          </div>
        </div>
      </div>`;
    },
    wire: (s) => {
      const state = { dir: "down", body: "body1", hair: "hair1", tab: "BODY", vis: { body: true, hair: true } };
      const stage = s.querySelector(".cc-stage");
      const setLayer = (which, kind) => {
        const el = stage.querySelector(`[data-layer="${which}"]`);
        el.dataset.kind = kind;
        el.style.backgroundImage = `url('${charSpriteURL(kind, state.dir)}')`;
        el.style.display = state.vis[which] ? "block" : "none";
      };
      const refreshPreview = () => { setLayer("body", state.body); setLayer("hair", state.hair); };
      // direction carousel
      const dirLabel = s.querySelector("[data-dirlabel]");
      const stepDir = (n) => {
        let i = CHAR.dirs.indexOf(state.dir);
        i = (i + n + CHAR.dirs.length) % CHAR.dirs.length;
        state.dir = CHAR.dirs[i];
        dirLabel.textContent = CHAR.dirLabels[state.dir];
        refreshPreview();
        s.querySelectorAll(".cc-mini").forEach((m) => m.classList.toggle("sel", m.dataset.mini === state.dir));
      };
      s.querySelectorAll("[data-dir]").forEach((b) => b.addEventListener("click", () => stepDir(Number(b.dataset.dir))));
      s.querySelectorAll(".cc-mini").forEach((m) => m.addEventListener("click", () => {
        state.dir = m.dataset.mini; dirLabel.textContent = CHAR.dirLabels[state.dir]; refreshPreview();
        s.querySelectorAll(".cc-mini").forEach((x) => x.classList.toggle("sel", x === m));
      }));
      // grid build per tab
      const grid = s.querySelector("[data-grid]");
      const buildGrid = () => {
        const layer = state.tab === "BODY" ? "body" : state.tab === "HAIR" ? "hair" : null;
        const opts = layer ? CHAR[layer] : [];
        if (!layer) {
          // placeholder tiles for layers without art (faithful to the game's grid)
          grid.innerHTML = Array.from({ length: 6 }, (_, i) =>
            `<div class="cc-tile placeholder"><span class="cc-tlabel">${state.tab} ${String(i + 1).padStart(2, "0")}</span></div>`).join("");
          return;
        }
        grid.innerHTML = opts.map((o, i) => {
          const sel = state[layer] === o;
          return `<div class="cc-tile ${sel ? "sel" : ""}" data-opt="${o}" data-layer="${layer}">
            <div class="cc-thumb" style="background-image:url('${charSpriteURL(o, "down")}')"></div>
            ${sel ? `<span class="cc-tlabel">${state.tab} ${String(i + 1).padStart(2, "0")}</span>` : ""}
          </div>`;
        }).join("");
        grid.querySelectorAll(".cc-tile[data-opt]").forEach((t) => t.addEventListener("click", () => {
          state[t.dataset.layer] = t.dataset.opt; clickSound("up"); refreshPreview(); buildGrid();
        }));
      };
      s.querySelectorAll(".cc-tab").forEach((t) => t.addEventListener("click", () => {
        state.tab = t.dataset.tab;
        s.querySelectorAll(".cc-tab").forEach((x) => x.classList.toggle("active", x === t));
        buildGrid();
      }));
      // visibility checkboxes (body/hair toggle the preview; others are inert placeholders)
      s.querySelectorAll("[data-vis]").forEach((b) => b.addEventListener("click", () => {
        const on = b.dataset.on === "true"; b.dataset.on = String(!on);
        const key = b.dataset.vis.toLowerCase();
        if (key === "body" || key === "hair") { state.vis[key] = !on; refreshPreview(); }
        clickSound("up");
      }));
      // randomize
      s.querySelector("[data-rand]").addEventListener("click", () => {
        state.body = CHAR.body[Math.floor(Math.random() * CHAR.body.length)];
        state.hair = CHAR.hair[Math.floor(Math.random() * CHAR.hair.length)];
        refreshPreview(); buildGrid();
      });
      // name + continue
      const name = s.querySelector("[data-ccname]"), cont = s.querySelector("[data-cont]");
      name.addEventListener("input", () => {
        name.value = name.value.replace(/[^A-Za-z ]/g, "");
        cont.disabled = name.value.trim() === "";
      });
      cont.addEventListener("click", () => !cont.disabled && toast(`Saved "${name.value.trim()}" + look → PetSelect.tscn`));
      refreshPreview(); buildGrid();
    },
  };

  /* close-button helper shared by overlay menus */
  function closeWire(s) {
    const x = s.querySelector(".x-btn");
    if (x) x.addEventListener("click", () => toast("Close menu"));
  }

  /* slider drag */
  function bindSlider(track) {
    const fill = track.querySelector(".fill"), grab = track.querySelector(".grab"),
      pct = track.parentElement.querySelector(".pct");
    const set = (clientX) => {
      const r = track.getBoundingClientRect();
      let v = Math.round(Math.max(0, Math.min(1, (clientX - r.left) / r.width)) * 100);
      fill.style.width = v + "%"; grab.style.left = v + "%"; pct.textContent = v + "%";
    };
    track.addEventListener("pointerdown", (e) => {
      track.setPointerCapture(e.pointerId); set(e.clientX); clickSound("down");
      const mv = (ev) => set(ev.clientX);
      const up = () => { track.removeEventListener("pointermove", mv); track.removeEventListener("pointerup", up); };
      track.addEventListener("pointermove", mv); track.addEventListener("pointerup", up);
    });
  }

  /* =========================================================== app shell === */
  const ORDER = [
    ["Start & Setup", [["opening", "Opening Menu"], ["chooser", "Dog Chooser"], ["petname", "Pet Name"]]],
    ["In-Game HUD", [["needs", "Pet Needs"], ["supplies", "Pet Supplies"], ["taxi", "Taxi"], ["notifs", "Notifications"]]],
    ["Systems", [["finance", "Financial Hub"], ["settings", "Settings"], ["pause", "Pause"], ["overview", "Game Overview"]]],
    ["Player Editor", [["charcreator", "Character Creator"]]],
  ];
  let current = "opening";
  const stage = $("#stage"), scaler = $("#scaler"), title = $("#stageTitle"), maps = $("#stageMaps");

  function fitScale() {
    const m = MENUS[current];
    const pad = 56;
    const sx = (stage.clientWidth - pad) / m.w, sy = (stage.clientHeight - pad) / m.h;
    scaler.style.transform = `scale(${Math.min(1.6, Math.max(0.3, Math.min(sx, sy)))})`;
  }
  function open(key) {
    stopSprites(scaler);
    current = key;
    const m = MENUS[key];
    scaler.innerHTML = m.build();
    scaler.classList.remove("fade-in"); void scaler.offsetWidth; scaler.classList.add("fade-in");
    m.wire && m.wire(scaler);
    title.textContent = m.title;
    maps.textContent = "→ " + m.maps;
    document.querySelectorAll(".rail__item").forEach((it) => it.classList.toggle("active", it.dataset.key === key));
    fitScale();
  }

  // build rail
  const rail = $("#railNav");
  ORDER.forEach(([grp, items]) => {
    const g = document.createElement("div"); g.className = "rail__group";
    g.innerHTML = `<h2>${grp}</h2>` + items.map(([k, n]) => `<div class="rail__item" data-key="${k}"><span class="rail__dot"></span>${n}</div>`).join("");
    rail.appendChild(g);
  });
  rail.addEventListener("click", (e) => { const it = e.target.closest(".rail__item"); if (it) open(it.dataset.key); });

  // sound toggle
  $("#soundBtn").addEventListener("click", (e) => {
    soundOn = !soundOn;
    e.currentTarget.dataset.on = String(soundOn);
    e.currentTarget.querySelector("span:last-child").textContent = soundOn ? "Sound On" : "Sound Off";
  });

  bindPress(document);
  window.addEventListener("resize", fitScale);
  open("opening");
})();
