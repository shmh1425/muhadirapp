const invitationConfig = {
  eventName: "معرض إنجاز 2026",
  context: "مشاريع التخرج بكلية الحاسبات – ضمن ملتقى المهنة والابتكار 2026",
  booth: "31",
  time: "من 11 صباحًا إلى 2 ظهرًا",
  date: "الثلاثاء 9 يونيو 2026م",
  location: "بهو قاعة الملك عبدالعزيز – المدينة الجامعية بالعابدية",
};

const invitationTypes = {
  general: {
    heading: "دعوة لزيارة مشروع مُحضِر",
    cardHeading: "مشروع مُحضِر | MUHADIR",
    message:
      "يسرّنا دعوتكم لزيارة بوث مشروع مُحضِر في معرض إنجاز 2026، والتعرّف على نظامنا الذكي لإدارة الحضور الجامعي بطريقة أكثر دقة وسهولة.",
    cta: "زورونا في بوث 31",
    label: "دعوة عامة",
    note: "حل رقمي لمشكلة واقعية داخل البيئة الجامعية.",
  },
  doctor: {
    fallbackHeading: "دعوة خاصة لأعضاء هيئة التدريس",
    message:
      "يسرّ فريق مُحضِر دعوتكم لزيارة بوثنا في معرض إنجاز 2026، والاطلاع على مشروعنا الذكي لإدارة الحضور الجامعي ومناقشة فكرته من منظور أكاديمي وتطبيقي.",
    cta: "يشرفنا حضوركم في بوث 31",
    label: "دعوة أكاديمية خاصة",
    note: "نثمّن حضوركم الكريم وملاحظاتكم القيّمة.",
  },
  engineers44: {
    heading: "دعوة خاصة لمهندسات دفعة 44",
    cardHeading: "مهندسات دفعة 44",
    message:
      "يسعدنا دعوتكن لزيارة بوث مشروع مُحضِر في معرض إنجاز 2026، ومشاركتكن ثمرة رحلتنا في مشروع التخرج.",
    cta: "ننتظركن في بوث 31",
    label: "دعوة دفعة 44",
    note: "حضوركن يعني لنا الكثير في هذه اللحظة المميزة.",
  },
  colleague: {
    fallbackHeading: "دعوة خاصة لزملاء التخصص",
    message:
      "يسعدنا دعوتكِ لزيارة بوث مشروع مُحضِر في معرض إنجاز 2026، والتعرّف على تجربة مشروعنا من الفكرة إلى الحل التقني.",
    cta: "ننتظركِ في بوث 31",
    label: "دعوة زميلة تخصص",
    note: "نسعد بمشاركتكِ تفاصيل الفكرة والتحديات التقنية.",
  },
};

const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

document.querySelectorAll("[data-event]").forEach((element) => {
  const key = element.dataset.event;
  if (Object.hasOwn(invitationConfig, key)) {
    element.textContent = invitationConfig[key];
  }
});

function normalizeParam(value) {
  return value ? value.trim().replace(/\s+/g, " ") : "";
}

function getSelectedInvitation() {
  const params = new URLSearchParams(window.location.search);
  const requestedType = normalizeParam(params.get("type")) || "general";
  const type = Object.hasOwn(invitationTypes, requestedType) ? requestedType : "general";
  const template = invitationTypes[type];
  const name = normalizeParam(params.get("name"));
  const title = normalizeParam(params.get("title"));
  const titledName = [title, name].filter(Boolean).join(" ");
  const personalizedHeading =
    (type === "doctor" || type === "colleague") && name
      ? `دعوة خاصة إلى ${titledName}`
      : template.heading || template.fallbackHeading || invitationTypes.general.heading;

  return {
    type,
    heading: personalizedHeading,
    cardHeading: template.cardHeading || template.label || invitationTypes.general.cardHeading,
    message: template.message,
    cta: template.cta,
    label: template.label,
    note: template.note,
    recipient: (type === "doctor" || type === "colleague") && name ? titledName : "",
  };
}

function bindSelectedInvitation(invitation) {
  document.documentElement.dataset.inviteType = invitation.type;
  document.title = `${invitation.heading} | ${invitationConfig.eventName}`;

  const bindings = [
    ["[data-invite-heading]", invitation.heading],
    ["[data-invite-card-heading]", invitation.cardHeading],
    ["[data-invite-message]", invitation.message],
    ["[data-invite-label]", invitation.label],
    ["[data-invite-note]", invitation.note],
  ];

  bindings.forEach(([selector, value]) => {
    document.querySelectorAll(selector).forEach((element) => {
      element.textContent = value;
    });
  });

  document.querySelectorAll("[data-invite-heading]").forEach((element) => {
    if (!invitation.recipient) return;

    const prefix = document.createElement("span");
    prefix.className = "heading-line";
    prefix.textContent = "دعوة خاصة إلى";

    const separator = document.createTextNode(" ");

    const recipient = document.createElement("span");
    recipient.className = "heading-line heading-recipient";
    recipient.textContent = invitation.recipient;

    element.replaceChildren(prefix, separator, recipient);
  });

  document.querySelectorAll("[data-invite-cta]").forEach((element) => {
    element.textContent = invitation.cta;
  });
}

bindSelectedInvitation(getSelectedInvitation());

const progress = document.querySelector(".scroll-progress");

function updateScrollProgress() {
  if (!progress) return;
  const scrollable = document.documentElement.scrollHeight - window.innerHeight;
  const ratio = scrollable > 0 ? window.scrollY / scrollable : 0;
  progress.style.width = `${Math.min(Math.max(ratio, 0), 1) * 100}%`;
}

window.addEventListener("scroll", updateScrollProgress, { passive: true });
updateScrollProgress();

const revealElements = document.querySelectorAll(".reveal");

if ("IntersectionObserver" in window) {
  const revealObserver = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("visible");
          revealObserver.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.16 }
  );

  revealElements.forEach((element) => revealObserver.observe(element));
} else {
  revealElements.forEach((element) => element.classList.add("visible"));
}

function enableTilt(card) {
  card.addEventListener("pointermove", (event) => {
    if (prefersReducedMotion || window.innerWidth < 760) return;

    const rect = card.getBoundingClientRect();
    const x = (event.clientX - rect.left) / rect.width;
    const y = (event.clientY - rect.top) / rect.height;
    const rotateY = (x - 0.5) * -13;
    const rotateX = (y - 0.5) * 13;

    card.style.setProperty("--tilt-x", `${rotateX.toFixed(2)}deg`);
    card.style.setProperty("--tilt-y", `${rotateY.toFixed(2)}deg`);
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

document.querySelectorAll(".tilt-card").forEach(enableTilt);

const particleField = document.querySelector("[data-particles]");

if (particleField && !prefersReducedMotion) {
  for (let index = 0; index < 34; index += 1) {
    const particle = document.createElement("span");
    particle.className = "particle";
    particle.style.left = `${Math.random() * 100}%`;
    particle.style.bottom = `${-10 - Math.random() * 25}%`;
    particle.style.animationDuration = `${7 + Math.random() * 9}s`;
    particle.style.animationDelay = `${Math.random() * 8}s`;
    particle.style.setProperty("--drift", `${Math.random() * 120 - 60}px`);
    particleField.appendChild(particle);
  }
}

document.querySelectorAll(".magnetic").forEach((button) => {
  button.addEventListener("pointermove", (event) => {
    if (prefersReducedMotion || window.innerWidth < 760) return;

    const rect = button.getBoundingClientRect();
    const x = event.clientX - rect.left - rect.width / 2;
    const y = event.clientY - rect.top - rect.height / 2;

    button.style.transform = `translate(${x * 0.08}px, ${y * 0.12}px) translateY(-3px)`;
  });

  button.addEventListener("pointerleave", () => {
    button.style.transform = "";
  });
});
