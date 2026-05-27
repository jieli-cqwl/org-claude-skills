const loginContent = {
  password: {
    title: '密码登录',
    copy: '展示账号和密码入口占位，不采集真实凭据。',
    showQr: false,
  },
  sms: {
    title: '验证码登录',
    copy: '展示手机号和验证码入口占位，不发送真实短信。',
    showQr: false,
  },
  qr: {
    title: '二维码登录',
    copy: '展示扫码登录入口占位，不生成真实扫码会话。',
    showQr: true,
  },
};

const defaultState = {
  loginMethod: 'password',
  renewalCollapsed: false,
  announcementExpanded: false,
  downloadClicks: 0,
  supportClicks: 0,
};

const state = { ...defaultState };

function getRequiredElement(selector) {
  const element = document.querySelector(selector);
  if (!element) {
    throw new Error(`Missing prototype element: ${selector}`);
  }
  return element;
}

function renderLogin(method) {
  const content = loginContent[method] || loginContent.password;
  document.querySelectorAll('[data-login-target]').forEach((button) => {
    const selected = button.dataset.loginTarget === method;
    button.setAttribute('aria-selected', String(selected));
  });
  getRequiredElement('[data-testid="login-panel-title"]').textContent = content.title;
  getRequiredElement('[data-testid="login-panel-copy"]').textContent = content.copy;
  getRequiredElement('[data-testid="qr-panel"]').hidden = !content.showQr;
}

function renderRenewal() {
  getRequiredElement('[data-testid="renewal-banner"]').classList.toggle('is-collapsed', state.renewalCollapsed);
  getRequiredElement('[data-testid="renewal-dismiss"]').textContent = state.renewalCollapsed ? '提示已收起' : '收起提示';
}

function renderAnnouncement() {
  const detail = getRequiredElement('[data-testid="announcement-detail"]');
  const toggle = getRequiredElement('[data-testid="announcement-toggle"]');
  detail.hidden = !state.announcementExpanded;
  toggle.setAttribute('aria-expanded', String(state.announcementExpanded));
  toggle.textContent = state.announcementExpanded ? '收起公告' : '展开公告';
}

function setStatus(selector, label, count) {
  getRequiredElement(selector).textContent = `${label}反馈 ${count} 次：仅本页原型状态，无外部跳转或真实集成。`;
}

function bindLoginTabs() {
  document.querySelectorAll('[data-login-target]').forEach((button) => {
    button.addEventListener('click', () => {
      state.loginMethod = button.dataset.loginTarget;
      renderLogin(state.loginMethod);
    });
  });
}

function bindRenewal() {
  getRequiredElement('[data-testid="renewal-dismiss"]').addEventListener('click', () => {
    state.renewalCollapsed = true;
    renderRenewal();
  });
  getRequiredElement('[data-testid="renewal-restore"]').addEventListener('click', () => {
    state.renewalCollapsed = false;
    renderRenewal();
  });
}

function bindAuxiliaryEntries() {
  getRequiredElement('[data-testid="download-button"]').addEventListener('click', () => {
    state.downloadClicks += 1;
    setStatus('[data-testid="download-status"]', '下载入口', state.downloadClicks);
  });
  getRequiredElement('[data-testid="support-button"]').addEventListener('click', () => {
    state.supportClicks += 1;
    setStatus('[data-testid="support-status"]', '客服入口', state.supportClicks);
  });
  getRequiredElement('[data-testid="announcement-toggle"]').addEventListener('click', () => {
    state.announcementExpanded = !state.announcementExpanded;
    renderAnnouncement();
  });
}

function initializePrototype() {
  bindLoginTabs();
  bindRenewal();
  bindAuxiliaryEntries();
  renderLogin(state.loginMethod);
  renderRenewal();
  renderAnnouncement();
}

initializePrototype();
