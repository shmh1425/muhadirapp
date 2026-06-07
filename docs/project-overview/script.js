(function () {
  "use strict";

  const STORAGE_KEY = "muhadir-overview-lang";
  const THEME_KEY = "muhadir-overview-theme";
  const IMG = window.MUHADIR_ASSETS || "../../assets/images/";
  let lang = localStorage.getItem(STORAGE_KEY) || "ar";

  const ICONS = {
    nfc: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect width="18" height="18" x="3" y="3" rx="2"/><path d="M7 7h.01M7 12h.01M7 17h.01M12 7h.01M12 12h.01M12 17h.01M17 7h.01M17 12h.01M17 17h.01"/></svg>',
    qr: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect width="5" height="5" x="3" y="3" rx="1"/><rect width="5" height="5" x="16" y="3" rx="1"/><rect width="5" height="5" x="3" y="16" rx="1"/><path d="M21 16h-3a2 2 0 0 0-2 2v3M21 21v.01M12 12h.01M12 16h.01M12 8h.01M12 20h.01M16 12h.01M16 16h.01M16 8h.01M16 20h.01M8 12h.01M8 16h.01M8 8h.01M8 20h.01"/></svg>',
    ble: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m7 7 10 10-5 5V2l5 5L7 17"/></svg>',
    map: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z"/><circle cx="12" cy="10" r="3"/></svg>',
    bot: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 8V4H8"/><rect width="16" height="12" x="4" y="8" rx="2"/><path d="M2 14h2M20 14h2M15 13v2M9 13v2"/></svg>',
    bell: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/></svg>',
    lock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="16" r="1"/><rect width="18" height="11" x="3" y="10" rx="2"/><path d="M7 10V7a5 5 0 0 1 10 0v3"/></svg>',
    db: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5"/><path d="M3 12c0 1.66 4 3 9 3s9-1.34 9-3"/></svg>',
    phone:
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="7" y="2" width="10" height="20" rx="2"/><path d="M11 18h2"/></svg>',
    cloud:
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 17.5a4.5 4.5 0 0 0-1.7-8.7 6 6 0 0 0-11.6 1.8A4 4 0 0 0 7 18h12a3 3 0 0 0 1-0.5Z"/></svg>',
    server:
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="4" width="18" height="6" rx="2"/><rect x="3" y="14" width="18" height="6" rx="2"/><path d="M7 7h.01M7 17h.01"/></svg>',
    key:
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 7l-3 3"/><path d="M17 7l3 3"/><path d="M14 7a5 5 0 1 0-2 4l2 2h3v-3h-3l-1-1"/></svg>',
    wifi:
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 12.5a10 10 0 0 1 14 0"/><path d="M8.5 16a5 5 0 0 1 7 0"/><path d="M12 20h.01"/></svg>',
    checkCircle:
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="m9 12 2 2 4-4"/></svg>',
    upload:
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><path d="M17 8l-5-5-5 5"/><path d="M12 3v12"/></svg>',
    student:
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 10v6M2 10l10-5 10 5-10 5z"/><path d="M6 12v5c0 1 2 3 6 3s6-2 6-3v-5"/></svg>',
    lecturer:
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 4h16v10H4z"/><path d="M8 20h8"/><path d="M12 14v6"/></svg>',
    security:
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10"/></svg>',
    clipboard:
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect width="8" height="4" x="8" y="2" rx="1"/><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/></svg>',
  };

  const attendanceMethods = [
    {
      icon: "nfc",
      tagAr: "لمسة + دون اتصال",
      tagEn: "Tap & Offline",
      titleAr: "حضور NFC",
      titleEn: "NFC Attendance",
      descAr: "سجّل حضورك بلمسة واحدة عبر البطاقة الرقمية، مع دعم العمل دون اتصال بالإنترنت ومزامنة البيانات لاحقاً.",
      descEn: "Check in with one tap using your digital card—with offline support and data sync when connectivity returns.",
      chipsAr: ["سريع", "آمن"],
      chipsEn: ["Fast", "Secure"],
    },
    {
      icon: "qr",
      tagAr: "ديناميكي + موقع",
      tagEn: "Dynamic + Geo",
      titleAr: "رموز QR ديناميكية",
      titleEn: "Dynamic QR Codes",
      descAr: "يتم إنشاء رمز QR متغير لكل جلسة حضور مع قيود جغرافية للتحقق من وجود الطالب داخل الموقع المسموح.",
      descEn: "A new QR code for each session, with geographic restrictions to confirm the student is in the allowed location.",
      chipsAr: ["متجدد", "مرتبط بالموقع"],
      chipsEn: ["Dynamic", "Location-aware"],
    },
    {
      icon: "ble",
      tagAr: "قرب + مزامنة",
      tagEn: "Proximity + Sync",
      titleAr: "حضور البلوتوث",
      titleEn: "Bluetooth Attendance",
      descAr: "يكتشف النظام أجهزة الطلاب القريبة ويسجل الحضور تلقائياً، مع دعم التشغيل عبر الإنترنت أو دون اتصال.",
      descEn: "Detects nearby student devices and records attendance automatically—with online or offline operation.",
      chipsAr: ["قرب", "تلقائي"],
      chipsEn: ["Proximity", "Automatic"],
    },
    {
      icon: "clipboard",
      tagAr: "مرونة المحاضر",
      tagEn: "Lecturer flexibility",
      titleAr: "الحضور اليدوي",
      titleEn: "Manual Attendance",
      descAr: "يوفّر مرونة كاملة للمحاضر في تسجيل الحضور وإدارته، حتى في حالات انقطاع الإنترنت، مع مزامنة البيانات تلقائياً عند عودة الاتصال.",
      descEn: "Gives lecturers full flexibility to record and manage attendance—even offline—with automatic sync when the network returns.",
      chipsAr: ["بإشراف المحاضر", "احتياطي"],
      chipsEn: ["Lecturer-controlled", "Fallback"],
    },
  ];

  const stats = [
    { value: "4", labelAr: "قنوات حضور", labelEn: "Attendance Channels" },
    { value: "3", labelAr: "أدوار مستخدم", labelEn: "User Roles" },
    { value: "24/7", labelAr: "وصول رقمي", labelEn: "Digital Access" },
    { value: "2030", labelAr: "مواءمة الرؤية", labelEn: "Vision Alignment" },
  ];

  const features = [
    {
      icon: "security",
      tagAr: "تحقق الهوية",
      tagEn: "Identity verification",
      titleAr: "تحقق آمن من الهوية",
      titleEn: "Secure identity verification",
      descAr: "يتيح لموظفي الأمن التحقق من هوية الطالبات عبر البطاقات الرقمية مع المحافظة على الخصوصية والصلاحيات المخصصة لكل دور.",
      descEn: "Security staff verify student identity through digital cards while respecting privacy and role-based permissions.",
    },
    {
      icon: "bell",
      tagAr: "تنبيهات فورية",
      tagEn: "Real-time alerts",
      titleAr: "تنبيهات",
      titleEn: "Notifications",
      descAr: "يرسل النظام إشعارات فورية للطلاب عند تأخير أو إلغاء المحاضرات، مع تنبيهات الحضور والغياب والتحديثات الأكاديمية لضمان اطلاعهم على آخر المستجدات.",
      descEn: "The system sends students instant notifications when lectures are delayed or cancelled, plus attendance and absence alerts and academic updates so they stay on top of what matters.",
    },
    {
      icon: "upload",
      titleAr: "إدارة الأعذار إلكترونياً",
      titleEn: "Electronic excuse management",
      descAr: "يمكن للطلاب رفع الأعذار مباشرة ومتابعة حالة الطلب، بينما يستطيع المحاضر مراجعتها واعتمادها بسهولة.",
      descEn: "Students upload excuses and track request status; lecturers review and approve them in one workflow.",
    },
    {
      icon: "bot",
      secondary: true,
      titleAr: "مساعد أكاديمي",
      titleEn: "Academic assistant",
      descAr: "يجيب عن استفسارات الطلاب ويساعدهم في الوصول السريع للمعلومات والخدمات داخل التطبيق.",
      descEn: "Answers student questions and helps them reach information and services inside the app quickly.",
    },
  ];

  const users = [
    {
      icon: "student",
      titleAr: "الطلاب",
      titleEn: "Students",
      textAr: "تسجيل الحضور، متابعة الغياب، تقديم الأعذار، واستقبال التنبيهات.",
      textEn: "Check in, view attendance, submit excuses, and receive alerts.",
      bulletsAr: ["تسجيل الحضور", "متابعة الغياب", "رفع الأعذار"],
      bulletsEn: ["Check-in", "Track absence", "Submit excuses"],
    },
    {
      icon: "lecturer",
      titleAr: "المحاضرون",
      titleEn: "Lecturers",
      textAr: "إنشاء الجلسات، متابعة الحضور، وإدارة سجلات الطلاب.",
      textEn: "Create sessions, track attendance, and manage student records.",
      bulletsAr: ["إنشاء جلسات", "تقارير حضور", "إدارة السجلات"],
      bulletsEn: ["Create sessions", "Attendance reports", "Manage records"],
    },
    {
      icon: "security",
      titleAr: "أمن القبول",
      titleEn: "Security Staff",
      textAr: "التحقق من هوية الطالبة عند بوابات الحرم عبر بطاقة رقمية آمنة.",
      textEn: "Verify student identity at campus gates using secure digital cards.",
      bulletsAr: ["مسح NFC/QR", "التحقق من الهوية", "تسجيل الدخول"],
      bulletsEn: ["Scan NFC/QR", "Verify identity", "Log access"],
    },
  ];

  const gateTags = [
    { ar: "وصول حسب الدور", en: "Role-based access" },
    { ar: "عرض آمن", en: "Secure display" },
    { ar: "كاش دون اتصال", en: "Offline-ready cache" },
    { ar: "تحذير مسح مكرر", en: "Repeat scan warnings" },
  ];

  const gateDetails = [
    {
      ar: "<strong>الخطوة 1:</strong> يفتح الطالب تطبيق محضر ويعرض بطاقته الجامعية الرقمية التي تحتوي على معرّف آمن.",
      en: "<strong>Step 1:</strong> The student opens MUHADIR and shows a secure digital university card.",
    },
    {
      ar: "<strong>الخطوة 2:</strong> موظف الأمن يمسح NFC أو رمز QR الديناميكي المرتبط بهوية الطالب وجلسة الدخول الحالية.",
      en: "<strong>Step 2:</strong> Security scans NFC or a dynamic QR tied to the student identity and the current gate session.",
    },
    {
      ar: "<strong>الخطوة 3:</strong> محضر يتحقق فورياً من الهوية والحالة وصلاحيات الدخول وفق قواعد الأمان المحددة.",
      en: "<strong>Step 3:</strong> MUHADIR instantly verifies identity, status, and access permissions based on security rules.",
    },
    {
      ar: "<strong>الخطوة 4:</strong> يُمنح الدخول أو يُرفض مع تسجيل السبب تلقائياً وإشعار الجهات عند الحاجة.",
      en: "<strong>Step 4:</strong> Access is allowed or denied with reason logging, and notifications when needed.",
    },
  ];

  const stackItems = [
    {
      ar: "تطبيق Flutter",
      en: "Flutter App",
      tagAr: "الواجهة",
      tagEn: "Client",
      icon: "phone",
      accent: "flutter",
      detailAr: "واجهة واحدة لـ iOS و Android",
      detailEn: "One UI for iOS & Android",
    },
    {
      ar: "Firebase Auth",
      en: "Firebase Auth",
      tagAr: "الهوية",
      tagEn: "Identity",
      icon: "key",
      accent: "firebase",
      img: "firebase_logo.png",
      detailAr: "مصادقة آمنة وأدوار",
      detailEn: "Secure auth & roles",
    },
    {
      ar: "Cloud Firestore",
      en: "Cloud Firestore",
      tagAr: "البيانات",
      tagEn: "Data",
      icon: "cloud",
      accent: "firebase",
      img: "firebase_logo.png",
      detailAr: "مزامنة فورية وبيانات محمية",
      detailEn: "Live sync & protected data",
    },
    {
      ar: "تخزين محلي",
      en: "Local Cache",
      tagAr: "دون اتصال",
      tagEn: "Offline",
      icon: "server",
      accent: "cache",
      detailAr: "يعمل بدون إنترنت",
      detailEn: "Works offline",
    },
  ];

  function t(ar, en) {
    return lang === "ar" ? ar : en;
  }

  function applyLang() {
    const html = document.documentElement;
    html.lang = lang;
    html.dir = lang === "ar" ? "rtl" : "ltr";

    document.querySelectorAll("[data-ar][data-en]").forEach((el) => {
      const val = el.getAttribute(lang === "ar" ? "data-ar" : "data-en");
      if (val == null) return;
      if (el.classList.contains("tcard-link")) {
        const ico = el.querySelector(".tcard-link-ico");
        el.textContent = "";
        if (ico) el.appendChild(ico);
        el.append(" " + val);
      } else {
        el.textContent = val;
      }
    });

    renderStats();
    renderAttendanceMethods();
    renderFeatures();
    renderUsers();
    renderGate();
    renderStack();
    localStorage.setItem(STORAGE_KEY, lang);

    document.querySelectorAll(".lang-seg-btn[data-lang]").forEach((btn) => {
      btn.classList.toggle("active", btn.getAttribute("data-lang") === lang);
      btn.setAttribute("aria-pressed", btn.getAttribute("data-lang") === lang ? "true" : "false");
    });
  }

  function applyTheme(theme) {
    const html = document.documentElement;
    if (theme === "dark") html.setAttribute("data-theme", "dark");
    else html.removeAttribute("data-theme");
  }

  function initThemeToggle() {
    const btn = document.getElementById("themeToggle");
    if (!btn) return;

    const stored = localStorage.getItem(THEME_KEY);
    const prefersDark = window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches;
    let theme = stored || (prefersDark ? "dark" : "light");

    const sync = () => {
      applyTheme(theme);
      btn.setAttribute("aria-pressed", theme === "dark" ? "true" : "false");
      btn.setAttribute("aria-label", theme === "dark" ? "Switch to light mode" : "Switch to dark mode");
    };

    sync();

    btn.addEventListener("click", () => {
      theme = theme === "dark" ? "light" : "dark";
      localStorage.setItem(THEME_KEY, theme);
      sync();
    });
  }

  function renderStats() {
    const grid = document.getElementById("statsGrid");
    if (!grid) return;
    grid.innerHTML = stats
      .map(
        (s, idx) => `
      <article class="stat-card reveal" data-stat-card style="--stat-progress: ${68 + idx * 8}%">
        <span class="stat-ring" aria-hidden="true"></span>
        <span class="stat-value" data-stat-value="${s.value}">${s.value}</span>
        <span class="stat-label">${t(s.labelAr, s.labelEn)}</span>
        <span class="stat-progress" aria-hidden="true"><span></span></span>
      </article>`
      )
      .join("");
    observeReveals(grid.querySelectorAll(".reveal"));
    initDashboardCounters(grid.querySelectorAll("[data-stat-value]"));
  }

  function initDashboardCounters(nodes) {
    const values = Array.from(nodes || document.querySelectorAll("[data-stat-value]"));
    if (!values.length) return;

    const reduced = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (reduced || !("IntersectionObserver" in window)) {
      values.forEach((el) => {
        el.textContent = el.getAttribute("data-stat-value") || el.textContent;
      });
      return;
    }

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          const el = entry.target;
          observer.unobserve(el);
          const target = el.getAttribute("data-stat-value") || "";
          const match = target.match(/^(\d+)(.*)$/);
          if (!match) {
            el.textContent = target;
            return;
          }

          const end = Number(match[1]);
          const suffix = match[2] || "";
          const duration = end > 100 ? 950 : 650;
          const start = performance.now();
          const tick = (now) => {
            const ratio = Math.min(1, (now - start) / duration);
            const eased = 1 - Math.pow(1 - ratio, 3);
            el.textContent = `${Math.round(end * eased)}${suffix}`;
            if (ratio < 1) requestAnimationFrame(tick);
          };
          el.textContent = `0${suffix}`;
          requestAnimationFrame(tick);
        });
      },
      { threshold: 0.35 }
    );

    values.forEach((el) => observer.observe(el));
  }

  function bindExpandCards(container, cardSelector, detailSelector = ".feature-desc") {
    if (!container) return;
    const cards = Array.from(container.querySelectorAll(cardSelector));
    const setActive = (card, active) => {
      card.classList.toggle("active", active);
      card.setAttribute("aria-expanded", active ? "true" : "false");
      const desc = card.querySelector(detailSelector);
      if (desc) desc.setAttribute("aria-hidden", active ? "false" : "true");
    };
    const closeAll = () => cards.forEach((c) => setActive(c, false));

    cards.forEach((card) => {
      const toggle = () => {
        const isActive = card.classList.contains("active");
        closeAll();
        if (!isActive) setActive(card, true);
      };
      card.addEventListener("click", toggle);
      card.addEventListener("keydown", (e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          toggle();
        }
      });
    });
  }

  function renderAttendanceMethods() {
    const grid = document.getElementById("attendanceMethodsGrid");
    if (!grid) return;
    grid.innerHTML = attendanceMethods
      .map((m, idx) => {
        const extra = m.featured ? " feature-card--featured" : "";
        const tag = m.tagAr ? `<span class="feature-tag">${t(m.tagAr, m.tagEn)}</span>` : "";
        const chips = (lang === "ar" ? m.chipsAr : m.chipsEn) || [];
        return `
      <article class="feature-card feature-card--method feature-card--method-${m.icon} reveal${extra}" role="button" tabindex="0" aria-expanded="false" data-method-idx="${idx}" data-tilt-card>
        <div class="feature-top">
          <div class="feature-icon" aria-hidden="true">${ICONS[m.icon] || ""}</div>
          <div class="feature-head">
            ${tag}
            <h3>${t(m.titleAr, m.titleEn)}</h3>
          </div>
        </div>
        <div class="method-chip-row" aria-hidden="true">${chips.map((chip) => `<span>${chip}</span>`).join("")}</div>
        <div class="feature-desc" aria-hidden="true">${t(m.descAr, m.descEn)}</div>
        <div class="feature-line" aria-hidden="true"></div>
      </article>`;
      })
      .join("");
    observeReveals(grid.querySelectorAll(".reveal"));
    bindExpandCards(grid, "[data-method-idx]");
  }

  function renderFeatures() {
    const grid = document.getElementById("featuresGrid");
    if (!grid) return;
    grid.innerHTML = features
      .map((f, idx) => {
        const title = t(f.titleAr, f.titleEn);
        const desc = t(f.descAr, f.descEn);
        const extra = [
          f.featured ? " feature-card--featured" : "",
          f.secondary ? " feature-card--secondary" : "",
        ].join("");
        const tag = f.tagAr
          ? `<span class="feature-tag">${t(f.tagAr, f.tagEn)}</span>`
          : "";
        return `
      <article class="feature-card feature-card--dynamic reveal${extra}" role="button" tabindex="0" aria-expanded="false" data-feature-idx="${idx}" data-tilt-card>
        <div class="feature-top">
          <div class="feature-icon" aria-hidden="true">${ICONS[f.icon] || ""}</div>
          <div class="feature-head">
            ${tag}
            <h3>${title}</h3>
          </div>
        </div>
        <div class="feature-desc" aria-hidden="true">${desc}</div>
        <div class="feature-line" aria-hidden="true"></div>
      </article>`;
      })
      .join("");
    observeReveals(grid.querySelectorAll(".reveal"));
    bindExpandCards(grid, "[data-feature-idx]");
  }

  function renderUsers() {
    const grid = document.getElementById("usersGrid");
    if (!grid) return;
    grid.innerHTML = users
      .map(
        (u) => `
      <article class="user-card reveal">
        <div class="user-icon" aria-hidden="true">${ICONS[u.icon] || ""}</div>
        <h3>${t(u.titleAr, u.titleEn)}</h3>
        <p class="user-desc">${t(u.textAr, u.textEn)}</p>
        <div class="user-features">
          ${(lang === "ar" ? u.bulletsAr : u.bulletsEn).map((b) => `<span class="user-chip">${b}</span>`).join("")}
        </div>
      </article>`
      )
      .join("");
    observeReveals(grid.querySelectorAll(".reveal"));
  }

  function renderGate() {
    const tags = document.getElementById("gateTags");
    if (tags) {
      tags.innerHTML = gateTags
        .map(
          (g) => `
        <div class="gate-tag">
          ${ICONS.lock}
          <span>${t(g.ar, g.en)}</span>
        </div>`
        )
        .join("");
    }

    const detail = document.getElementById("gateDetailText");
    const prev = document.getElementById("gatePrev");
    const next = document.getElementById("gateNext");
    if (!detail || !prev || !next) return;

    let cur = 0;

    const goTo = (i) => {
      cur = Math.max(0, Math.min(gateDetails.length - 1, i));
      detail.innerHTML = t(gateDetails[cur].ar, gateDetails[cur].en);
      prev.disabled = cur === 0;
      next.textContent = cur === gateDetails.length - 1 ? t("إعادة", "Reset") : t("التالي", "Next");
    };

    const move = (dir) => {
      if (dir === 1 && cur === gateDetails.length - 1) {
        goTo(0);
        return;
      }
      goTo(cur + dir);
    };

    prev.addEventListener("click", () => move(-1));
    next.addEventListener("click", () => move(1));
    goTo(0);
  }

  function stackItemIcon(item) {
    if (item.img) {
      return `<img src="${IMG}${item.img}" alt="" width="28" height="28" loading="lazy" />`;
    }
    if (item.accent === "flutter") {
      return `<img src="${IMG}app_icon.png" alt="" width="28" height="28" loading="lazy" />`;
    }
    return ICONS[item.icon] || ICONS.db;
  }

  let stackSwapIdx = 0;
  let stackSwapReady = false;

  function stackSwapOffset(idx) {
    const rtl = document.documentElement.dir === "rtl";
    const sign = rtl ? 1 : -1;
    return sign * idx * 100;
  }

  function stackSwapGoTo(idx, animate) {
    const track = document.getElementById("stackTrack");
    const dotsWrap = document.getElementById("stackDots");
    const n = stackItems.length;
    if (!track || !n) return;

    stackSwapIdx = ((idx % n) + n) % n;
    track.style.transition = animate === false ? "none" : "transform 0.45s var(--ease)";
    track.style.transform = `translateX(${stackSwapOffset(stackSwapIdx)}%)`;

    if (dotsWrap) {
      dotsWrap.querySelectorAll(".stack-swap__dot").forEach((dot, i) => {
        const on = i === stackSwapIdx;
        dot.classList.toggle("active", on);
        dot.setAttribute("aria-selected", on ? "true" : "false");
      });
    }
  }

  function renderStack() {
    const track = document.getElementById("stackTrack");
    const dotsWrap = document.getElementById("stackDots");
    if (!track || !dotsWrap) return;

    track.innerHTML = stackItems
      .map(
        (item, idx) => `
      <article class="stack-swap-card" data-accent="${item.accent || ""}" data-idx="${idx}" role="tabpanel">
        <span class="stack-swap-card__tag">${t(item.tagAr, item.tagEn)}</span>
        <div class="stack-swap-card__icon" aria-hidden="true">${stackItemIcon(item)}</div>
        <h3 class="stack-swap-card__title">${t(item.ar, item.en)}</h3>
        <p class="stack-swap-card__detail">${t(item.detailAr, item.detailEn)}</p>
      </article>`
      )
      .join("");

    dotsWrap.innerHTML = stackItems
      .map(
        (_, idx) => `
      <button type="button" class="stack-swap__dot${idx === stackSwapIdx ? " active" : ""}" data-idx="${idx}" role="tab" aria-selected="${idx === stackSwapIdx ? "true" : "false"}" aria-label="${idx + 1}"></button>`
      )
      .join("");

    stackSwapGoTo(stackSwapIdx, false);
    requestAnimationFrame(() => stackSwapGoTo(stackSwapIdx, true));
  }

  function initStackSwap() {
    if (stackSwapReady) return;
    const swap = document.getElementById("stackSwap");
    const prev = document.getElementById("stackPrev");
    const next = document.getElementById("stackNext");
    const viewport = document.getElementById("stackViewport");
    const dotsWrap = document.getElementById("stackDots");
    if (!swap || !viewport) return;

    stackSwapReady = true;

    prev?.addEventListener("click", () => stackSwapGoTo(stackSwapIdx - 1));
    next?.addEventListener("click", () => stackSwapGoTo(stackSwapIdx + 1));

    dotsWrap?.addEventListener("click", (e) => {
      const dot = e.target.closest(".stack-swap__dot");
      if (!dot) return;
      stackSwapGoTo(Number(dot.getAttribute("data-idx") || "0"));
    });

    let touchStartX = 0;
    viewport.addEventListener(
      "touchstart",
      (e) => {
        touchStartX = e.changedTouches[0]?.clientX ?? 0;
      },
      { passive: true }
    );
    viewport.addEventListener(
      "touchend",
      (e) => {
        const dx = (e.changedTouches[0]?.clientX ?? 0) - touchStartX;
        if (Math.abs(dx) < 48) return;
        const rtl = document.documentElement.dir === "rtl";
        const forward = rtl ? dx > 0 : dx < 0;
        stackSwapGoTo(stackSwapIdx + (forward ? 1 : -1));
      },
      { passive: true }
    );
  }

  function observeReveals(nodes) {
    const targets = nodes || document.querySelectorAll(".reveal:not(.visible)");
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("visible");
            observer.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.1, rootMargin: "0px 0px -40px 0px" }
    );
    targets.forEach((el) => observer.observe(el));
  }

  function initScrollProgress() {
    const bar = document.getElementById("scrollProgress");
    const backTop = document.getElementById("backTop");

    window.addEventListener(
      "scroll",
      () => {
        const scrollTop = window.scrollY;
        const docHeight = document.documentElement.scrollHeight - window.innerHeight;
        const progress = docHeight > 0 ? (scrollTop / docHeight) * 100 : 0;
        if (bar) bar.style.width = `${progress}%`;
        if (backTop) backTop.classList.toggle("visible", scrollTop > 400);
      },
      { passive: true }
    );
  }

  function initSmoothAnchors() {
    document.querySelectorAll('a[href^="#"]').forEach((link) => {
      link.addEventListener("click", (e) => {
        const href = link.getAttribute("href");
        if (!href || href === "#") return;
        const target = document.querySelector(href);
        if (!target) return;
        e.preventDefault();
        target.scrollIntoView({ behavior: "smooth" });
      });
    });
  }

  function initOverviewPhoneDemo() {
    const phone = document.querySelector(".hero-phone .phone");
    if (!phone) return;
    const btn = phone.querySelector(".phone-checkin");
    const out = phone.querySelector(".phone-result");
    if (!btn || !out) return;

    btn.addEventListener("click", () => {
      out.classList.add("success");
      out.textContent = t("تم تسجيل حضورك بنجاح", "Attendance recorded successfully");
    });

    const tabs = Array.from(phone.querySelectorAll(".tab[data-method]"));
    if (tabs.length) {
      const titleEl = phone.querySelector(".phone-title");
      const labelEl = phone.querySelector(".nfc-label");

      const copyByMethod = {
        nfc: {
          titleAr: "التحضير عبر NFC",
          titleEn: "NFC Check-in",
          labelAr: "قرّب جوالك من بطاقة الدكتور",
          labelEn: "Tap your phone on the lecturer’s card",
        },
        qr: {
          titleAr: "التحضير عبر QR",
          titleEn: "QR Check-in",
          labelAr: "امسح QR Code",
          labelEn: "Scan the QR code",
        },
        ble: {
          titleAr: "التحضير عبر البلوتوث",
          titleEn: "BLE Check-in",
          labelAr: "فعّل البلوتوث للتحقق التلقائي",
          labelEn: "Enable Bluetooth for auto verification",
        },
      };

      const setMethodCopy = (method) => {
        const c = copyByMethod[method] || copyByMethod.nfc;
        if (titleEl) {
          titleEl.setAttribute("data-ar", c.titleAr);
          titleEl.setAttribute("data-en", c.titleEn);
          titleEl.textContent = t(c.titleAr, c.titleEn);
        }
        if (labelEl) {
          labelEl.setAttribute("data-ar", c.labelAr);
          labelEl.setAttribute("data-en", c.labelEn);
          labelEl.textContent = t(c.labelAr, c.labelEn);
        }
      };

      // Sync initial state
      const initial = tabs.find((x) => x.classList.contains("active"))?.getAttribute("data-method") || "nfc";
      setMethodCopy(initial);

      tabs.forEach((tab) => {
        tab.addEventListener("click", () => {
          tabs.forEach((x) => {
            x.classList.toggle("active", x === tab);
            x.setAttribute("aria-selected", x === tab ? "true" : "false");
          });
          const method = tab.getAttribute("data-method") || "nfc";
          setMethodCopy(method);
        });
      });
    }
  }

  function initSolutionReveal() {
    const scene = document.getElementById("problemSolutionCard");
    if (!scene) return;
    const innerParticles = scene.querySelector(".flip-particles");
    const dotPositions = [
      [12, 20],
      [30, 70],
      [55, 15],
      [75, 60],
      [88, 30],
      [20, 85],
      [65, 90],
      [45, 45],
      [90, 75],
      [8, 55],
    ];

    if (innerParticles && !innerParticles.childElementCount) {
      dotPositions.forEach(([x, y], i) => {
        const d = document.createElement("div");
        d.className = "flip-dot";
        d.style.left = `${x}%`;
        d.style.top = `${y}%`;
        d.style.animationDelay = `${(i * 0.4).toFixed(1)}s`;
        d.style.animationDuration = `${(3.5 + i * 0.2).toFixed(1)}s`;
        innerParticles.appendChild(d);
      });
    }

    function setFlipped(flipped) {
      scene.classList.toggle("flipped", flipped);
      scene.setAttribute("aria-pressed", flipped ? "true" : "false");
      scene.setAttribute(
        "aria-label",
        flipped ? t("اضغط للعودة للمشكلة", "Tap to return to the problem") : t("اضغط لعرض الحل", "Tap to view the solution")
      );
    }

    scene.addEventListener("click", () => setFlipped(!scene.classList.contains("flipped")));
    scene.addEventListener("keydown", (e) => {
      if (e.key === "Enter" || e.key === " ") {
        e.preventDefault();
        setFlipped(!scene.classList.contains("flipped"));
      }
    });
  }

  function initTeamCards() {
    const grid = document.getElementById("teamGrid");
    if (!grid) return;
    const cards = Array.from(grid.querySelectorAll(".tcard"));
    if (!cards.length) return;

    const setActive = (card, active) => {
      card.classList.toggle("active", active);
    };
    const clear = () => cards.forEach((c) => setActive(c, false));

    cards.forEach((card) => {
      const toggle = () => {
        const was = card.classList.contains("active");
        clear();
        if (!was) setActive(card, true);
      };
      card.addEventListener("click", (e) => {
        // Let normal anchor navigation happen; still set active for feedback.
        toggle();
      });
      card.addEventListener("keydown", (e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          toggle();
          // For anchors, Enter should also follow the link (Space shouldn't).
          if (e.key === "Enter" && card.tagName === "A") {
            card.click();
          }
        }
      });
    });
  }

  let dynamicTiltReady = false;
  function initDynamicTilt() {
    if (dynamicTiltReady) return;
    const canHover = window.matchMedia && window.matchMedia("(hover: hover) and (pointer: fine)").matches;
    const reduced = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (!canHover || reduced) return;

    dynamicTiltReady = true;
    const selector = "[data-tilt-card]";
    const reset = (card) => {
      card.classList.remove("is-tilting");
      card.style.removeProperty("--tilt-x");
      card.style.removeProperty("--tilt-y");
      card.style.removeProperty("--glow-x");
      card.style.removeProperty("--glow-y");
    };

    document.addEventListener(
      "pointermove",
      (e) => {
        const card = e.target.closest?.(selector);
        if (!card) return;
        const rect = card.getBoundingClientRect();
        const x = (e.clientX - rect.left) / rect.width;
        const y = (e.clientY - rect.top) / rect.height;
        card.classList.add("is-tilting");
        card.style.setProperty("--tilt-x", `${(0.5 - y) * 4.5}deg`);
        card.style.setProperty("--tilt-y", `${(x - 0.5) * 5.5}deg`);
        card.style.setProperty("--glow-x", `${x * 100}%`);
        card.style.setProperty("--glow-y", `${y * 100}%`);
      },
      { passive: true }
    );

    document.addEventListener(
      "pointerleave",
      (e) => {
        const card = e.target.closest?.(selector);
        if (card) reset(card);
      },
      true
    );
  }

  document.querySelectorAll(".lang-seg-btn[data-lang]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const next = btn.getAttribute("data-lang");
      if (!next || next === lang) return;
      lang = next;
      applyLang();
      observeReveals(document.querySelectorAll(".reveal:not(.visible)"));
    });
  });

  document.getElementById("backTop")?.addEventListener("click", () => {
    window.scrollTo({ top: 0, behavior: "smooth" });
  });

  applyLang();
  initThemeToggle();
  observeReveals();
  initScrollProgress();
  initSmoothAnchors();
  initOverviewPhoneDemo();
  initSolutionReveal();
  initStackSwap();
  initTeamCards();
  initDynamicTilt();

})();
