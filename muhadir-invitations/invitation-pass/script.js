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
      "نلقاكم في معرض إنجاز 2026، بوث 31، لتجربة مُحضِر والتعرّف على حضور جامعي أذكى وأسهل.",
    cta: "نلقاكم في بوث 31",
    hook: "بدأت التجربة بالمسح... وتكتمل بحضوركم في بوث 31.",
    syncRegistering: "جاري تسجيلكم ضمن حضور مُحضِر...",
  },
  doctor: {
    heading: "تم تسجيلكم ضمن حضور مُحضِر",
    label: "دعوة أكاديمية خاصة",
    message:
      "يشرفنا حضوركم في معرض إنجاز 2026، بوث 31، للاطلاع على مُحضِر ومناقشة فكرته من منظور أكاديمي وتطبيقي.",
    cta: "يشرفنا حضوركم في بوث 31",
    hook: "بدأت التجربة بالمسح... وتكتمل بحضوركم في بوث 31.",
    syncRegistering: "جاري تسجيلكم ضمن حضور مُحضِر...",
    defaultTitle: "د",
  },
  engineers44: {
    heading: "تم تسجيلكن ضمن حضور مُحضِر",
    label: "دعوة مهندسات دفعة 44",
    message:
      "نلقاكن في معرض إنجاز 2026، بوث 31، لنشارككن ثمرة رحلتنا في مشروع التخرج ولحظة نعتز بها.",
    cta: "ننتظركن في بوث 31",
    hook: "بدأت التجربة بالمسح... وتكتمل بحضوركن في بوث 31.",
    syncRegistering: "جاري تسجيلكن ضمن حضور مُحضِر...",
  },
  colleague: {
    heading: "تم تسجيلكِ ضمن حضور مُحضِر",
    label: "دعوة من التخصص",
    message:
      "نلقاكِ في معرض إنجاز 2026، بوث 31، لتجربة الفكرة عن قرب ومعرفة كيف حوّلنا تحدي الحضور الجامعي إلى حل تقني ذكي.",
    cta: "نلقاكِ في بوث 31",
    hook: "بدأت التجربة بالمسح... وتكتمل بحضوركِ في بوث 31.",
    syncRegistering: "جاري تسجيلكِ ضمن حضور مُحضِر...",
    defaultTitle: "م",
  },
  family: {
    heading: "تم تسجيلكم ضمن حضور مُحضِر",
    label: "دعوة من القلب",
    message:
      "نلقاكم في معرض إنجاز 2026، بوث 31، لمشاركتنا لحظة مميزة من ختام رحلة مشروع التخرج.",
    cta: "ننتظركم في بوث 31",
    hook: "بدأت التجربة بالمسح... وتكتمل بحضوركم في بوث 31.",
    syncRegistering: "جاري تسجيلكم ضمن حضور مُحضِر...",
  },
};

const personalizedAudienceCopy = {
  general: {
    heading: "تم تسجيلك ضمن حضور مُحضِر",
    message:
      "نلقاك في معرض إنجاز 2026، بوث 31، لتجربة مُحضِر والتعرّف على حضور جامعي أذكى وأسهل.",
    cta: "نلقاك في بوث 31",
    hook: "بدأت التجربة بالمسح... وتكتمل بحضورك في بوث 31.",
    syncRegistering: "جاري تسجيلك ضمن حضور مُحضِر...",
  },
  doctor: {
    heading: "تم تسجيلك ضمن حضور مُحضِر",
    message:
      "يشرفنا حضورك في معرض إنجاز 2026، بوث 31، للاطلاع على مُحضِر ومناقشة فكرته من منظور أكاديمي وتطبيقي.",
    cta: "يشرفنا حضورك في بوث 31",
    hook: "بدأت التجربة بالمسح... وتكتمل بحضورك في بوث 31.",
    syncRegistering: "جاري تسجيلك ضمن حضور مُحضِر...",
  },
  engineers44: {
    heading: "تم تسجيلكِ ضمن حضور مُحضِر",
    message:
      "نلقاكِ في معرض إنجاز 2026، بوث 31، لنشارككِ ثمرة رحلتنا في مشروع التخرج ولحظة نعتز بها.",
    cta: "ننتظركِ في بوث 31",
    hook: "بدأت التجربة بالمسح... وتكتمل بحضوركِ في بوث 31.",
    syncRegistering: "جاري تسجيلكِ ضمن حضور مُحضِر...",
  },
  colleague: {
    heading: "تم تسجيلكِ ضمن حضور مُحضِر",
    message:
      "نلقاكِ في معرض إنجاز 2026، بوث 31، لتجربة الفكرة عن قرب ومعرفة كيف حوّلنا تحدي الحضور الجامعي إلى حل تقني ذكي.",
    cta: "نلقاكِ في بوث 31",
    hook: "بدأت التجربة بالمسح... وتكتمل بحضوركِ في بوث 31.",
    syncRegistering: "جاري تسجيلكِ ضمن حضور مُحضِر...",
  },
  family: {
    heading: "تم تسجيلك ضمن حضور مُحضِر",
    message:
      "نلقاك في معرض إنجاز 2026، بوث 31، لمشاركتنا لحظة مميزة من ختام رحلة مشروع التخرج.",
    cta: "ننتظرك في بوث 31",
    hook: "بدأت التجربة بالمسح... وتكتمل بحضورك في بوث 31.",
    syncRegistering: "جاري تسجيلك ضمن حضور مُحضِر...",
  },
};

const FINAL_HOOK = "بدأت التجربة بالمسح... وتكتمل بحضوركم في بوث 31.";

const params = new URLSearchParams(window.location.search);
const requestedType = params.get("type") || "general";
const inviteType = hasOwn(audienceCopy, requestedType) ? requestedType : "general";
const hasName = hasRecipientName();
const currentCopy = audienceCopy[inviteType];
const selectedCopy = resolveAudienceCopy(inviteType, hasName);
const reducedMotionQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
const customCopy = {
  heading: getUrlText("heading"),
  label: getUrlText("label"),
  message: getUrlText("message"),
  cta: getUrlText("cta"),
  hook: getUrlText("hook"),
};
const resolvedCopy = {
  heading: customCopy.heading || selectedCopy.heading,
  label: customCopy.label || selectedCopy.label,
  message: customCopy.message || selectedCopy.message,
  cta: customCopy.cta || selectedCopy.cta,
  hook: customCopy.hook || selectedCopy.hook || FINAL_HOOK,
};
const syncMessages = [
  "جاري قراءة رمز الدعوة...",
  selectedCopy.syncRegistering || "جاري تسجيلك ضمن حضور مُحضِر...",
  "جاري تجهيز بطاقة الدعوة الرقمية...",
];

const TIMING = {
  syncTotal: reducedMotionQuery.matches ? 400 : 4800,
  messageInterval: reducedMotionQuery.matches ? 120 : 1800,
  successHold: reducedMotionQuery.matches ? 300 : 2100,
  revealSettle: reducedMotionQuery.matches ? 0 : 1300,
};

function setText(selector, value) {
  const element = document.querySelector(selector);
  if (element) {
    element.textContent = value;
  }
}

function getUrlText(name) {
  return (params.get(name) || "").trim();
}

function hasOwn(object, key) {
  return Object.prototype.hasOwnProperty.call(object, key);
}

function hasRecipientName() {
  return Boolean(getUrlText("name"));
}

function resolveAudienceCopy(type, hasName) {
  if (!hasName) {
    return audienceCopy[type];
  }

  return {
    ...audienceCopy[type],
    ...(personalizedAudienceCopy[type] || {}),
  };
}

function normalizeTitle(rawTitle, fallbackTitle) {
  const title = (rawTitle || fallbackTitle || "")
    .trim()
    .replace(/\s+/gu, " ")
    .replace(/\.{2,}/gu, ".");

  if (!title) {
    return "";
  }

  const compactTitle = title.replace(/\./gu, "");
  if (compactTitle === "د" || compactTitle === "م") {
    return `${compactTitle}.`;
  }

  return title;
}

function formatRecipient() {
  const name = (params.get("name") || "").trim();
  if (!name) {
    return "";
  }

  const rawTitle = params.get("title");
  const fallbackTitle =
    rawTitle === null && (inviteType === "doctor" || inviteType === "colleague")
      ? currentCopy.defaultTitle
      : "";
  const title = normalizeTitle(rawTitle, fallbackTitle);
  return [title, name].filter(Boolean).join(" ");
}

function getHeading() {
  return resolvedCopy.heading || currentCopy.fallbackHeading;
}

function applyInvitationCopy() {
  const recipient = formatRecipient();
  const heading = getHeading();

  document.documentElement.dataset.inviteType = inviteType;
  document.title = `MUHADIR PASS | ${resolvedCopy.label}`;

  setText("[data-audience-label]", resolvedCopy.label);
  setText("[data-heading]", heading);
  setText("[data-success-heading]", heading);
  setText("[data-message]", resolvedCopy.message);
  setText("[data-cta]", resolvedCopy.cta);
  setText(".success-hook", resolvedCopy.hook);
  setText(".final-hook", resolvedCopy.hook);
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

function updateSyncMessage(index, immediate = false) {
  const textElement = document.querySelector("[data-sync-text]");
  const steps = document.querySelectorAll("[data-sync-step]");

  if (!textElement) {
    return;
  }

  const applyMessage = () => {
    textElement.textContent = syncMessages[index] || syncMessages[syncMessages.length - 1];
    textElement.classList.remove("is-changing");

    steps.forEach((step, stepIndex) => {
      step.classList.toggle("is-active", stepIndex === index);
      step.classList.toggle("is-done", stepIndex < index);
    });
  };

  if (immediate || reducedMotionQuery.matches) {
    applyMessage();
    return;
  }

  textElement.classList.add("is-changing");
  window.setTimeout(applyMessage, 280);
}

async function runSyncSequence() {
  setPhase("sync");

  if (reducedMotionQuery.matches) {
    updateSyncMessage(syncMessages.length - 1);
    await wait(TIMING.syncTotal);
    return;
  }

  updateSyncMessage(0, true);
  await wait(TIMING.messageInterval);

  for (let index = 1; index < syncMessages.length; index += 1) {
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
  await wait(TIMING.revealSettle);
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
