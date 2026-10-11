(() => {
  const colors = { blue: "#4d7cfe", violet: "#8b6cff", coral: "#ff6a55", lime: "#b8f03a" };
  const names = Object.keys(colors);
  const root = document.documentElement;

  const apply = (name) => {
    root.dataset.accent = name;
    const icon = document.querySelector('link[rel="icon"][type="image/svg+xml"]');
    if (icon) {
      const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect width="32" height="32" rx="6" fill="#0b0c10"/><g transform="translate(6.4 6.4) scale(0.6)"><rect width="14" height="32" fill="${colors[name]}"/><path d="M18 2H30V30H18" fill="none" stroke="#f2f4f8" stroke-width="4"/></g></svg>`;
      icon.href = `data:image/svg+xml,${encodeURIComponent(svg)}`;
    }
  };

  apply(names[Math.floor(Math.random() * names.length)]);

  document.addEventListener("DOMContentLoaded", () => {
    const button = document.querySelector(".hero-mark-button");
    if (button) {
      button.addEventListener("click", () => {
        apply(names[(names.indexOf(root.dataset.accent) + 1) % names.length]);
      });
    }
  });
})();
