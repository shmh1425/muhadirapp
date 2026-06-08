const form = document.getElementById("link-form");
const baseUrlInput = document.getElementById("base-url");
const typeSelect = document.getElementById("invite-type");
const titleInput = document.getElementById("title-field");
const nameInput = document.getElementById("name-field");
const customHeadingInput = document.getElementById("custom-heading");
const customLabelInput = document.getElementById("custom-label");
const customMessageInput = document.getElementById("custom-message");
const customCtaInput = document.getElementById("custom-cta");
const customHookInput = document.getElementById("custom-hook");
const bulkRecipientsInput = document.getElementById("bulk-recipients");
const outputPanel = document.getElementById("output-panel");
const singleResult = document.getElementById("single-result");
const generatedUrlOutput = document.getElementById("generated-url");
const copyUrlBtn = document.getElementById("copy-url-btn");
const copyAllBtn = document.getElementById("copy-all-btn");
const downloadQrBtn = document.getElementById("download-qr-btn");
const qrMount = document.getElementById("qr-mount");
const qrFallback = document.getElementById("qr-fallback");
const lengthWarning = document.getElementById("length-warning");
const previewType = document.getElementById("preview-type");
const previewRecipient = document.getElementById("preview-recipient");
const bulkOutput = document.getElementById("bulk-output");

const TYPE_LABELS = {
  general: "دعوة عامة",
  doctor: "دعوة أكاديمية",
  engineers44: "مهندسات 44",
  colleague: "زميلة تخصص",
  family: "دعوة خاصة",
};

const DEFAULT_TITLES = {
  doctor: "د",
  colleague: "م",
};

const CUSTOM_PARAM_NAMES = {
  heading: "heading",
  label: "label",
  message: "message",
  cta: "cta",
  hook: "hook",
};

const QR_FALLBACK_MESSAGE =
  "تعذر توليد QR تلقائيًا، يمكن نسخ الرابط وتحويله إلى QR من أي أداة خارجية.";
const LONG_URL_WARNING = "الرابط طويل جدًا، اختصري النصوص لضمان قراءة QR بسهولة.";
const LONG_URL_LIMIT = 1800;
const QR_RENDER_SIZE = 320;
const QR_DOWNLOAD_PADDING = 32;

let currentGeneratedUrl = "";
let generatedLinks = [];
let lastAutoTitle = "";

function detectDefaultBaseUrl() {
  const { origin, pathname } = window.location;
  const folderPath = pathname.replace(/[^/]*$/, "");
  return `${origin}${folderPath}`;
}

function normalizeBaseUrl(rawBase) {
  const trimmedBase = rawBase.trim();
  if (!trimmedBase) {
    return "";
  }

  return trimmedBase.endsWith("/") ? trimmedBase : `${trimmedBase}/`;
}

function normalizeTitle(rawTitle) {
  const trimmedTitle = rawTitle.trim().replace(/\s+/gu, " ").replace(/\.{2,}/gu, ".");
  return trimmedTitle;
}

function normalizeTitleForDisplay(rawTitle) {
  const normalizedTitle = normalizeTitle(rawTitle);
  if (!normalizedTitle) {
    return "";
  }

  const compactTitle = normalizedTitle.replace(/\./gu, "");
  if (compactTitle === "د" || compactTitle === "م") {
    return `${compactTitle}.`;
  }

  return normalizedTitle;
}

function encodePair(key, value) {
  return `${key}=${encodeURIComponent(value)}`;
}

function getCustomCopyParams() {
  const entries = {
    heading: customHeadingInput.value.trim(),
    label: customLabelInput.value.trim(),
    message: customMessageInput.value.trim(),
    cta: customCtaInput.value.trim(),
    hook: customHookInput.value.trim(),
  };

  return Object.fromEntries(Object.entries(entries).filter(([, value]) => value));
}

function buildPassUrl(baseUrl, type, title, name, customParams = {}) {
  const normalizedBase = normalizeBaseUrl(baseUrl);
  const params = [encodePair("type", type)];
  const normalizedTitle = normalizeTitle(title);
  const trimmedName = name.trim().replace(/\s+/gu, " ");

  if (normalizedTitle) {
    params.push(encodePair("title", normalizedTitle));
  }

  if (trimmedName) {
    params.push(encodePair("name", trimmedName));
  }

  Object.entries(CUSTOM_PARAM_NAMES).forEach(([fieldName, paramName]) => {
    const value = (customParams[fieldName] || "").trim();
    if (value) {
      params.push(encodePair(paramName, value));
    }
  });

  return `${normalizedBase}index.html?${params.join("&")}`;
}

function formatRecipient(title, name) {
  const trimmedName = name.trim().replace(/\s+/gu, " ");
  if (!trimmedName) {
    return "—";
  }

  const displayTitle = normalizeTitleForDisplay(title);
  return [displayTitle, trimmedName].filter(Boolean).join(" ");
}

function parseRecipientLine(rawLine) {
  const line = rawLine.trim();
  if (!line) {
    return null;
  }

  if (line.includes("|")) {
    const pipeIndex = line.indexOf("|");
    const title = line.slice(0, pipeIndex).trim();
    const name = line.slice(pipeIndex + 1).trim();
    return name ? { title, name } : null;
  }

  return { title: "", name: line };
}

function parseBulkRecipients() {
  return bulkRecipientsInput.value
    .split(/\r?\n/u)
    .map(parseRecipientLine)
    .filter(Boolean);
}

function resetSingleQrPanel() {
  qrMount.innerHTML = "";
  qrMount.hidden = false;
  qrFallback.hidden = true;
  downloadQrBtn.disabled = true;
}

function showSingleQrFallback() {
  qrMount.innerHTML = "";
  qrMount.hidden = true;
  qrFallback.hidden = false;
  downloadQrBtn.disabled = true;
}

function renderQrInto(mountElement, url, size = QR_RENDER_SIZE) {
  if (typeof QRCode === "undefined") {
    throw new Error("QR library unavailable");
  }

  mountElement.innerHTML = "";
  mountElement.dataset.qrSize = String(size);

  new QRCode(mountElement, {
    text: url,
    width: size,
    height: size,
    colorDark: "#000000",
    colorLight: "#ffffff",
    correctLevel: QRCode.CorrectLevel.M,
  });
}

function renderSingleQrCode(url) {
  resetSingleQrPanel();
  renderQrInto(qrMount, url);
  downloadQrBtn.disabled = false;
}

function getQrSourceElement(mountElement) {
  const canvas = mountElement.querySelector("canvas");
  const image = mountElement.querySelector("img");

  if (canvas) {
    return canvas;
  }

  if (image && image.src) {
    return image;
  }

  return null;
}

function composeQrDownloadCanvas(sourceElement, size) {
  const outputSize = size + QR_DOWNLOAD_PADDING * 2;
  const outputCanvas = document.createElement("canvas");
  outputCanvas.width = outputSize;
  outputCanvas.height = outputSize;

  const context = outputCanvas.getContext("2d");
  context.imageSmoothingEnabled = false;
  context.fillStyle = "#ffffff";
  context.fillRect(0, 0, outputSize, outputSize);
  context.drawImage(sourceElement, QR_DOWNLOAD_PADDING, QR_DOWNLOAD_PADDING, size, size);
  return outputCanvas;
}

function downloadQrFromMount(mountElement, fileStem) {
  const sourceElement = getQrSourceElement(mountElement);
  if (!sourceElement) {
    return;
  }

  const renderSize = Number(mountElement.dataset.qrSize) || QR_RENDER_SIZE;
  const dataUrl = composeQrDownloadCanvas(sourceElement, renderSize).toDataURL("image/png");
  const safeName =
    fileStem
      .trim()
      .replace(/[\\/:*?"<>|]+/gu, "-")
      .replace(/\s+/gu, "-")
      .slice(0, 80) || "invitation";
  const link = document.createElement("a");
  link.download = `muhadir-pass-${safeName}.png`;
  link.href = dataUrl;
  link.click();
}

async function writeClipboard(text) {
  if (navigator.clipboard && window.isSecureContext) {
    await navigator.clipboard.writeText(text);
    return;
  }

  const textarea = document.createElement("textarea");
  textarea.value = text;
  textarea.setAttribute("readonly", "");
  textarea.style.position = "fixed";
  textarea.style.insetInlineStart = "-9999px";
  document.body.append(textarea);
  textarea.select();
  document.execCommand("copy");
  textarea.remove();
}

function createButton(label, className = "btn btn-ghost") {
  const button = document.createElement("button");
  button.type = "button";
  button.className = className;
  button.textContent = label;
  return button;
}

function createBulkCard(recipient, index, baseUrl, type, customParams) {
  const displayName = formatRecipient(recipient.title, recipient.name);
  const finalUrl = buildPassUrl(baseUrl, type, recipient.title, recipient.name, customParams);
  generatedLinks.push({ displayName, url: finalUrl });

  const card = document.createElement("article");
  card.className = "recipient-card";

  const title = document.createElement("h3");
  title.textContent = displayName || `مستلم ${index + 1}`;

  const code = document.createElement("code");
  code.className = "recipient-url";
  code.dir = "ltr";
  code.textContent = finalUrl;

  const qrCard = document.createElement("div");
  qrCard.className = "recipient-qr-card";

  const qrCardMount = document.createElement("div");
  qrCardMount.className = "qr-mount";
  qrCardMount.setAttribute("aria-label", `QR code ${index + 1}`);

  const qrCardFallback = document.createElement("p");
  qrCardFallback.className = "qr-fallback";
  qrCardFallback.hidden = true;
  qrCardFallback.textContent = QR_FALLBACK_MESSAGE;

  qrCard.append(qrCardMount, qrCardFallback);

  const actions = document.createElement("div");
  actions.className = "recipient-actions";

  const copyButton = createButton("نسخ الرابط");
  const openLink = document.createElement("a");
  openLink.className = "btn btn-secondary";
  openLink.textContent = "فتح الدعوة";
  openLink.href = finalUrl;
  openLink.target = "_blank";
  openLink.rel = "noopener";

  const downloadButton = createButton("تحميل QR", "btn btn-secondary");
  downloadButton.disabled = true;

  copyButton.addEventListener("click", async () => {
    await writeClipboard(finalUrl);
    copyButton.textContent = "تم النسخ ✓";
    copyButton.classList.add("is-copied");
  });

  downloadButton.addEventListener("click", () => {
    downloadQrFromMount(qrCardMount, displayName);
  });

  actions.append(copyButton, openLink, downloadButton);
  card.append(title, code, qrCard, actions);

  if (finalUrl.length > LONG_URL_LIMIT) {
    const warning = document.createElement("p");
    warning.className = "url-warning";
    warning.textContent = LONG_URL_WARNING;
    card.append(warning);
  }

  try {
    renderQrInto(qrCardMount, finalUrl);
    downloadButton.disabled = false;
  } catch {
    qrCardMount.hidden = true;
    qrCardFallback.hidden = false;
  }

  return card;
}

function renderBulkResults(recipients, baseUrl, type, customParams) {
  bulkOutput.innerHTML = "";
  generatedLinks = [];

  recipients.forEach((recipient, index) => {
    bulkOutput.append(createBulkCard(recipient, index, baseUrl, type, customParams));
  });

  bulkOutput.hidden = recipients.length === 0;
  copyAllBtn.hidden = recipients.length === 0;
}

function renderSingleResult(baseUrl, type, title, name, customParams) {
  const finalUrl = buildPassUrl(baseUrl, type, title, name, customParams);
  currentGeneratedUrl = finalUrl;

  generatedUrlOutput.textContent = finalUrl;
  previewType.textContent = TYPE_LABELS[type] || type;
  previewRecipient.textContent = formatRecipient(title, name);
  lengthWarning.hidden = finalUrl.length <= LONG_URL_LIMIT;
  copyUrlBtn.classList.remove("is-copied");
  copyUrlBtn.textContent = "نسخ الرابط";

  try {
    renderSingleQrCode(finalUrl);
  } catch {
    showSingleQrFallback();
  }
}

async function handleGenerate(event) {
  event.preventDefault();

  const baseUrl = baseUrlInput.value.trim();
  const type = typeSelect.value;
  const title = titleInput.value;
  const name = nameInput.value;
  const customParams = getCustomCopyParams();
  const recipients = parseBulkRecipients();

  if (!baseUrl) {
    baseUrlInput.focus();
    return;
  }

  outputPanel.hidden = false;

  if (recipients.length > 0) {
    singleResult.hidden = true;
    currentGeneratedUrl = "";
    renderBulkResults(recipients, baseUrl, type, customParams);
    return;
  }

  singleResult.hidden = false;
  bulkOutput.hidden = true;
  bulkOutput.innerHTML = "";
  generatedLinks = [];
  copyAllBtn.hidden = true;
  renderSingleResult(baseUrl, type, title, name, customParams);
}

async function copyGeneratedUrl() {
  if (!currentGeneratedUrl) {
    return;
  }

  await writeClipboard(currentGeneratedUrl);
  copyUrlBtn.textContent = "تم النسخ ✓";
  copyUrlBtn.classList.add("is-copied");
}

async function copyAllGeneratedLinks() {
  if (generatedLinks.length === 0) {
    return;
  }

  const text = generatedLinks
    .map((item) => `${item.displayName}\n${item.url}`)
    .join("\n\n");
  await writeClipboard(text);
  copyAllBtn.textContent = "تم نسخ كل الروابط ✓";
  copyAllBtn.classList.add("is-copied");
}

function downloadSingleQrImage() {
  const fileName = formatRecipient(titleInput.value, nameInput.value);
  downloadQrFromMount(qrMount, fileName === "—" ? typeSelect.value : fileName);
}

function initDefaults() {
  baseUrlInput.value = detectDefaultBaseUrl();
}

function applyTypeDefaultTitle() {
  const defaultTitle = DEFAULT_TITLES[typeSelect.value] || "";
  const currentTitle = titleInput.value.trim();

  if (!currentTitle || currentTitle === lastAutoTitle) {
    titleInput.value = defaultTitle;
    lastAutoTitle = defaultTitle;
  }
}

form.addEventListener("submit", handleGenerate);
copyUrlBtn.addEventListener("click", copyGeneratedUrl);
copyAllBtn.addEventListener("click", copyAllGeneratedLinks);
downloadQrBtn.addEventListener("click", downloadSingleQrImage);
typeSelect.addEventListener("change", applyTypeDefaultTitle);
titleInput.addEventListener("input", () => {
  lastAutoTitle = "";
});
initDefaults();

if (typeof QRCode === "undefined") {
  qrFallback.textContent = QR_FALLBACK_MESSAGE;
}
