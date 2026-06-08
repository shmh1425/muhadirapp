const form = document.getElementById("link-form");
const baseUrlInput = document.getElementById("base-url");
const typeSelect = document.getElementById("invite-type");
const titleInput = document.getElementById("title-field");
const nameInput = document.getElementById("name-field");
const outputPanel = document.getElementById("output-panel");
const generatedUrlOutput = document.getElementById("generated-url");
const copyUrlBtn = document.getElementById("copy-url-btn");
const downloadQrBtn = document.getElementById("download-qr-btn");
const qrMount = document.getElementById("qr-mount");
const qrFallback = document.getElementById("qr-fallback");
const previewType = document.getElementById("preview-type");
const previewRecipient = document.getElementById("preview-recipient");

const TYPE_LABELS = {
  general: "دعوة عامة",
  doctor: "دعوة أكاديمية",
  engineers44: "مهندسات 44",
  colleague: "زميلة تخصص",
  family: "دعوة خاصة",
};

const QR_FALLBACK_MESSAGE =
  "تعذر توليد QR تلقائيًا، يمكن نسخ الرابط وتحويله إلى QR من أي أداة خارجية.";

let currentGeneratedUrl = "";

function detectDefaultBaseUrl() {
  const { origin, pathname } = window.location;
  const folderPath = pathname.replace(/[^/]*$/, "");
  return `${origin}${folderPath}`;
}

function normalizeBaseUrl(rawBase) {
  const trimmed = rawBase.trim();
  if (!trimmed) {
    return "";
  }
  return trimmed.endsWith("/") ? trimmed : `${trimmed}/`;
}

function normalizeTitleForUrl(rawTitle) {
  const trimmed = rawTitle.trim();
  if (!trimmed) {
    return "";
  }

  return trimmed.replace(/\.+$/u, "").replace(/\./gu, "");
}

function normalizeTitleForDisplay(rawTitle) {
  const urlTitle = normalizeTitleForUrl(rawTitle);
  if (!urlTitle) {
    return "";
  }

  return `${urlTitle}.`;
}

function buildPassUrl(baseUrl, type, title, name) {
  const normalizedBase = normalizeBaseUrl(baseUrl);
  const params = [];

  params.push(`type=${encodeURIComponent(type)}`);

  const urlTitle = normalizeTitleForUrl(title);
  const trimmedName = name.trim();

  if (urlTitle) {
    params.push(`title=${encodeURIComponent(urlTitle)}`);
  }

  if (trimmedName) {
    params.push(`name=${encodeURIComponent(trimmedName)}`);
  }

  return `${normalizedBase}index.html?${params.join("&")}`;
}

function formatRecipient(title, name) {
  const trimmedName = name.trim();
  if (!trimmedName) {
    return "—";
  }

  const displayTitle = normalizeTitleForDisplay(title);
  return [displayTitle, trimmedName].filter(Boolean).join(" ");
}

function resetQrPanel() {
  qrMount.innerHTML = "";
  qrMount.hidden = false;
  qrFallback.hidden = true;
  downloadQrBtn.disabled = true;
}

function showQrFallback() {
  qrMount.innerHTML = "";
  qrMount.hidden = true;
  qrFallback.hidden = false;
  downloadQrBtn.disabled = true;
}

function renderQrCode(url) {
  if (typeof QRCode === "undefined") {
    throw new Error("QR library unavailable");
  }

  resetQrPanel();

  new QRCode(qrMount, {
    text: url,
    width: 240,
    height: 240,
    colorDark: "#031119",
    colorLight: "#ffffff",
    correctLevel: QRCode.CorrectLevel.M,
  });

  downloadQrBtn.disabled = false;
}

async function handleGenerate(event) {
  event.preventDefault();

  const baseUrl = baseUrlInput.value.trim();
  const type = typeSelect.value;
  const title = titleInput.value;
  const name = nameInput.value;

  if (!baseUrl) {
    baseUrlInput.focus();
    return;
  }

  const finalUrl = buildPassUrl(baseUrl, type, title, name);
  currentGeneratedUrl = finalUrl;

  generatedUrlOutput.textContent = finalUrl;
  previewType.textContent = TYPE_LABELS[type] || type;
  previewRecipient.textContent = formatRecipient(title, name);
  outputPanel.hidden = false;
  copyUrlBtn.classList.remove("is-copied");
  copyUrlBtn.textContent = "نسخ الرابط";

  try {
    renderQrCode(finalUrl);
  } catch {
    showQrFallback();
  }
}

async function copyGeneratedUrl() {
  if (!currentGeneratedUrl) {
    return;
  }

  try {
    await navigator.clipboard.writeText(currentGeneratedUrl);
  } catch {
    generatedUrlOutput.textContent = currentGeneratedUrl;
    const range = document.createRange();
    range.selectNodeContents(generatedUrlOutput);
    const selection = window.getSelection();
    selection.removeAllRanges();
    selection.addRange(range);
    document.execCommand("copy");
    selection.removeAllRanges();
  }

  copyUrlBtn.textContent = "تم النسخ ✓";
  copyUrlBtn.classList.add("is-copied");
}

function downloadQrImage() {
  const canvas = qrMount.querySelector("canvas");
  const img = qrMount.querySelector("img");

  let dataUrl = "";
  if (canvas) {
    dataUrl = canvas.toDataURL("image/png");
  } else if (img && img.src) {
    dataUrl = img.src;
  }

  if (!dataUrl) {
    return;
  }

  const link = document.createElement("a");
  const type = typeSelect.value;
  const namePart = nameInput.value.trim().replace(/\s+/g, "-") || type;
  link.download = `muhadir-pass-${namePart}.png`;
  link.href = dataUrl;
  link.click();
}

function initDefaults() {
  baseUrlInput.value = detectDefaultBaseUrl();
}

form.addEventListener("submit", handleGenerate);
copyUrlBtn.addEventListener("click", copyGeneratedUrl);
downloadQrBtn.addEventListener("click", downloadQrImage);
initDefaults();

if (typeof QRCode === "undefined") {
  qrFallback.textContent = QR_FALLBACK_MESSAGE;
}
