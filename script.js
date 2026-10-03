const header = document.querySelector('.site-header');
const menuBtn = document.querySelector('.menu-button');
const navLinks = document.querySelector('.nav-links');

menuBtn?.addEventListener('click', () => {
  const open = header.classList.toggle('open');
  menuBtn.setAttribute('aria-expanded', String(open));
});

document.querySelectorAll('.nav-links a').forEach(link => {
  link.addEventListener('click', () => {
    header?.classList.remove('open');
    menuBtn?.setAttribute('aria-expanded', 'false');
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
