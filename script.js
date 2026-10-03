const header = document.querySelector('.site-header');
const menuBtn = document.querySelector('.menu-button');
const navLinks = document.querySelector('.nav-links');

function setMenuOpen(open) {
  if (!header || !menuBtn) return;
  header.classList.toggle('open', open);
  document.body.classList.toggle('menu-open', open);
  menuBtn.setAttribute('aria-expanded', String(open));
  menuBtn.textContent = open ? '×' : '☰';
  menuBtn.setAttribute('aria-label', open ? 'Close menu' : 'Open menu');
}

menuBtn?.addEventListener('click', () => {
  setMenuOpen(!header?.classList.contains('open'));
});

document.querySelectorAll('.nav-links a').forEach(link => {
  link.addEventListener('click', () => {
    setMenuOpen(false);
  });
});

const observer = new IntersectionObserver(entries => {
  entries.forEach(entry => {
    if (entry.isIntersecting) entry.target.classList.add('visible');
  });
}, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });

document.querySelectorAll('.reveal, .reveal-right').forEach(el => observer.observe(el));

if (window.matchMedia('(pointer:fine)').matches) {
  document.querySelectorAll('.tilt').forEach(card => {
    card.addEventListener('mousemove', e => {
      const rect = card.getBoundingClientRect();
      const x = (e.clientX - rect.left) / rect.width - 0.5;
      const y = (e.clientY - rect.top) / rect.height - 0.5;
      card.style.transform = `perspective(900px) rotateY(${x * 7}deg) rotateX(${-y * 7}deg) translateY(-2px)`;
    });

    card.addEventListener('mouseleave', () => {
      card.style.transform = '';
    });
  });
}

window.addEventListener('scroll', () => {
  document.body.classList.toggle('scrolled', window.scrollY > 24);
}, { passive: true });

const page = document.body.dataset.page;
document.querySelectorAll('.nav-links a').forEach(link => {
  const href = link.getAttribute('href') || '';
  if (
    (page === 'home' && href.startsWith('index.html#')) ||
    (page === 'conquest' && href === 'conquest.html') ||
    (page === 'story' && href === 'story.html')
  ) {
    link.classList.add('active');
  }
});


const evolutionStack = document.querySelector('.evolution-stack');
const evolutionButtons = [...document.querySelectorAll('.evolution-stage-button')];
const evolutionLayers = [...document.querySelectorAll('.evolution-card-layer')];
const evolutionDots = [...document.querySelectorAll('.evolution-progress span')];
const evolutionTrigger = document.querySelector('.evolution-trigger');
const evolutionStageLabel = document.querySelector('.evolution-info-stage');
const evolutionName = document.querySelector('.evolution-info-name');
const evolutionText = document.querySelector('.evolution-info-text');

const evolutionStages = [
  {
    stage: 'STAGE 1',
    name: 'YOUNG SAM',
    text: 'The beginning of the journey — before the road to Aster changes everything.'
  },
  {
    stage: 'STAGE 2',
    name: 'SAM OF ASTER',
    text: 'Forged by loss and battle, Sam returns stronger and carries the weight of Aster with him.'
  },
  {
    stage: 'STAGE 3 · LEGENDARY',
    name: 'LAST GUARDIAN',
    text: 'The final evolution — a legendary form shaped by the legacy of the Guardians of Aster.'
  }
];

let activeEvolutionStage = 0;

function setEvolutionStage(index) {
  if (!evolutionStack || !evolutionStages[index]) return;

  activeEvolutionStage = index;
  evolutionStack.dataset.activeStage = String(index);

  evolutionLayers.forEach((layer, layerIndex) => {
    layer.classList.toggle('active', layerIndex === index);
    layer.classList.toggle('past', layerIndex < index);
    layer.classList.toggle('future', layerIndex > index);
  });

  evolutionButtons.forEach((button, buttonIndex) => {
    const active = buttonIndex === index;
    button.classList.toggle('active', active);
    button.setAttribute('aria-selected', String(active));
  });

  evolutionDots.forEach((dot, dotIndex) => {
    dot.classList.toggle('active', dotIndex <= index);
  });

  const data = evolutionStages[index];
  if (evolutionStageLabel) evolutionStageLabel.textContent = data.stage;
  if (evolutionName) evolutionName.textContent = data.name;
  if (evolutionText) evolutionText.textContent = data.text;

  if (evolutionTrigger) {
    evolutionTrigger.firstChild.textContent = index === evolutionStages.length - 1
      ? 'VIEW FROM START '
      : 'EVOLVE HERO ';
  }
}

evolutionButtons.forEach((button, index) => {
  button.addEventListener('click', () => setEvolutionStage(index));
});

evolutionTrigger?.addEventListener('click', () => {
  const next = activeEvolutionStage === evolutionStages.length - 1
    ? 0
    : activeEvolutionStage + 1;
  setEvolutionStage(next);
});

setEvolutionStage(0);


document.addEventListener('click', event => {
  if (!header?.classList.contains('open')) return;
  const target = event.target;
  if (header.contains(target)) return;
  setMenuOpen(false);
});

document.addEventListener('keydown', event => {
  if (event.key === 'Escape') setMenuOpen(false);
});
