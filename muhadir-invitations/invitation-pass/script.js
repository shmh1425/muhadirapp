const invitationConfig = {
  eventName: "معرض إنجاز 2026",
  context: "مشاريع التخرج بكلية الحاسبات – ضمن ملتقى المهنة والابتكار 2026",
  booth: "31",
  time: "من 11 صباحًا إلى 2 ظهرًا",
  date: "الثلاثاء 9 يونيو 2026م",
  location: "بهو قاعة الملك عبدالعزيز – المدينة الجامعية بالعابدية",
};

const audienceCopy = {
  general: {
    heading: "تم تسجيلكم ضمن حضور مُحضِر",
    label: "دعوة عامة",
    message:
      "نلقاكم في معرض إنجاز 2026، بوث 31، لتجربة نظام مُحضِر والتعرّف على حضور جامعي أذكى وأسهل.",
    cta: "نلقاكم في بوث 31",
  },
  doctor: {
    fallbackHeading: "تم تسجيلكم ضمن حضور مُحضِر",
    label: "دعوة أكاديمية خاصة",
    message:
      "يشرفنا حضوركم في معرض إنجاز 2026، بوث 31، للاطلاع على مشروع مُحضِر ومناقشة فكرته من منظور أكاديمي وتطبيقي.",
    cta: "يشرفنا حضوركم في بوث 31",
    defaultTitle: "د",
  },
  engineers44: {
    heading: "تم تسجيلكن ضمن حضور مُحضِر",
    label: "دعوة مهندسات دفعة 44",
    message:
      "نلقاكن في معرض إنجاز 2026، بوث 31، لنشارككن ثمرة رحلتنا في مشروع التخرج ولحظة نعتز بها مع دفعة 44.",
    cta: "ننتظركن في بوث 31",
  },
  colleague: {
    fallbackHeading: "تم تسجيلكِ ضمن حضور مُحضِر",
    label: "دعوة من التخصص",
    message:
      "نلقاكِ في معرض إنجاز 2026، بوث 31، لتجربة الفكرة عن قرب ومعرفة كيف حوّلنا تحدي الحضور الجامعي إلى حل تقني ذكي.",
    cta: "نلقاكِ في بوث 31",
    defaultTitle: "م",
  },
  family: {
    heading: "تم تسجيلكم ضمن حضور مُحضِر",
    label: "دعوة من القلب",
    message:
      "نلقاكم في معرض إنجاز 2026، بوث 31، لمشاركتنا لحظة مميزة من ختام رحلة مشروع التخرج.",
    cta: "ننتظركم في بوث 31",
  },
};

const syncMessages = [
  "جاري قراءة رمز الدعوة...",
  "جاري تسجيلكم ضمن حضور مُحضِر...",
  "جاري تجهيز بطاقة الدعوة الرقمية...",
];

const FINAL_HOOK = "بدأت التجربة بالمسح... وتكتمل بحضوركم في بوث 31.";

const params = new URLSearchParams(window.location.search);
const requestedType = params.get("type") || "general";
const inviteType = Object.hasOwn(audienceCopy, requestedType) ? requestedType : "general";
const currentCopy = audienceCopy[inviteType];
const reducedMotionQuery = window.matchMedia("(prefers-reduced-motion: reduce)");

const TIMING = {
  syncTotal: reducedMotionQuery.matches ? 400 : 2600,
  messageInterval: reducedMotionQuery.matches ? 120 : 800,
  successHold: reducedMotionQuery.matches ? 300 : 1200,
};

function setText(selector, value) {
  const element = document.querySelector(selector);
  if (element) {
    element.textContent = value;
  }
}

function normalizeTitle(rawTitle, fallbackTitle) {
  const title = (rawTitle || fallbackTitle || "").trim().replace(/\.+$/u, "");
  return title ? `${title}.` : "";
}

function formatRecipient() {
  if (inviteType !== "doctor" && inviteType !== "colleague") {
    return "";
  }

  const name = (params.get("name") || "").trim();
  if (!name) {
    return "";
  }

  const title = normalizeTitle(params.get("title"), currentCopy.defaultTitle);
  return [title, name].filter(Boolean).join(" ");
}

function makePassId() {
  const typeCode = {
    general: "GEN",
    doctor: "ACD",
    engineers44: "E44",
    colleague: "COL",
    family: "FAM",
  }[inviteType];

  return `MHD-${invitationConfig.booth}-${typeCode}-2026`;
}

function getHeading() {
  return currentCopy.heading || currentCopy.fallbackHeading;
}

function applyInvitationCopy() {
  const recipient = formatRecipient();
  const heading = getHeading();

  document.documentElement.dataset.inviteType = inviteType;
  document.title = `MUHADIR PASS | ${currentCopy.label}`;

  setText("[data-audience-label]", currentCopy.label);
  setText("[data-heading]", heading);
  setText("[data-success-heading]", heading);
  setText("[data-message]", currentCopy.message);
  setText("[data-cta]", currentCopy.cta);
  setText(".success-hook", FINAL_HOOK);
  setText(".final-hook", FINAL_HOOK);
  setText("[data-pass-id]", makePassId());
  setText("[data-booth-display]", `بوث ${invitationConfig.booth}`);
  setText("[data-event]", invitationConfig.eventName);
  setText("[data-date]", invitationConfig.date);
  setText("[data-time]", invitationConfig.time);
  setText("[data-location]", invitationConfig.location);

  const recipientElement = document.querySelector("[data-recipient]");
  if (recipientElement) {
    recipientElement.textContent = recipient;
    recipientElement.hidden = !recipient;
  }
}

function setPhase(phase) {
  document.documentElement.dataset.phase = phase;

  const stages = {
    sync: document.querySelector('[data-stage="sync"]'),
    success: document.querySelector('[data-stage="success"]'),
    reveal: document.querySelector('[data-stage="reveal"]'),
  };

  Object.entries(stages).forEach(([name, element]) => {
    if (!element) {
      return;
    }
    element.hidden = name !== phase;
  });

  const card = document.querySelector(".pass-card");
  if (card) {
    card.setAttribute("aria-busy", phase === "sync" ? "true" : "false");
    card.classList.remove("is-success-pop", "is-unlocking");

    if (phase === "success") {
      card.classList.add("is-success-pop");
    }

    if (phase === "reveal") {
      card.classList.add("is-unlocking");
    }
  }
}

function wait(ms) {
  return new Promise((resolve) => {
    window.setTimeout(resolve, ms);
  });
}

function updateSyncMessage(index) {
  const textElement = document.querySelector("[data-sync-text]");
  const steps = document.querySelectorAll("[data-sync-step]");

  if (!textElement) {
    return;
  }

  textElement.classList.add("is-changing");

  window.setTimeout(() => {
    textElement.textContent = syncMessages[index] || syncMessages[syncMessages.length - 1];
    textElement.classList.remove("is-changing");

    steps.forEach((step, stepIndex) => {
      step.classList.toggle("is-active", stepIndex === index);
      step.classList.toggle("is-done", stepIndex < index);
    });
  }, reducedMotionQuery.matches ? 0 : 180);
}

async function runSyncSequence() {
  setPhase("sync");

  if (reducedMotionQuery.matches) {
    updateSyncMessage(syncMessages.length - 1);
    await wait(TIMING.syncTotal);
    return;
  }

  for (let index = 0; index < syncMessages.length; index += 1) {
    updateSyncMessage(index);
    // eslint-disable-next-line no-await-in-loop
    await wait(TIMING.messageInterval);
  }

  const remaining = TIMING.syncTotal - TIMING.messageInterval * syncMessages.length;
  if (remaining > 0) {
    await wait(remaining);
  }
}

async function runExperienceFlow() {
  await runSyncSequence();
  setPhase("success");
  await wait(TIMING.successHold);
  setPhase("reveal");
  await wait(reducedMotionQuery.matches ? 0 : 720);
  const card = document.querySelector(".pass-card");
  if (card) {
    card.classList.remove("is-unlocking");
  }
}

function setupCardTilt() {
  const card = document.querySelector(".pass-card");
  if (!card || reducedMotionQuery.matches) {
    return;
  }

  card.addEventListener("pointermove", (event) => {
    if (document.documentElement.dataset.phase !== "reveal") {
      return;
    }

    const rect = card.getBoundingClientRect();
    const x = (event.clientX - rect.left) / rect.width;
    const y = (event.clientY - rect.top) / rect.height;
    const tiltX = (0.5 - y) * 5;
    const tiltY = (x - 0.5) * 5;

    card.style.setProperty("--tilt-x", `${tiltX.toFixed(2)}deg`);
    card.style.setProperty("--tilt-y", `${tiltY.toFixed(2)}deg`);
    card.style.setProperty("--glow-x", `${(x * 100).toFixed(1)}%`);
    card.style.setProperty("--glow-y", `${(y * 100).toFixed(1)}%`);
  });

  card.addEventListener("pointerleave", () => {
    card.style.setProperty("--tilt-x", "0deg");
    card.style.setProperty("--tilt-y", "0deg");
    card.style.setProperty("--glow-x", "50%");
    card.style.setProperty("--glow-y", "50%");
  });
}

function addParticles() {
  const ambient = document.querySelector(".ambient");
  if (!ambient || reducedMotionQuery.matches) {
    return;
  }

  const particleCount = window.innerWidth < 700 ? 12 : 20;
  for (let index = 0; index < particleCount; index += 1) {
    const particle = document.createElement("span");
    particle.className = "particle";
    particle.style.insetInlineStart = `${Math.random() * 100}%`;
    particle.style.bottom = `${-8 - Math.random() * 24}%`;
    particle.style.setProperty("--drift", `${(Math.random() - 0.5) * 90}px`);
    particle.style.animationDelay = `${Math.random() * 7}s`;
    particle.style.animationDuration = `${7 + Math.random() * 8}s`;
    ambient.append(particle);
  }
}

applyInvitationCopy();
setupCardTilt();
addParticles();
runExperienceFlow();
