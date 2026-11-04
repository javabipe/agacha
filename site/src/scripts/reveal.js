import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

export function startReveal() {
  if (matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  gsap.registerPlugin(ScrollTrigger);
  gsap.utils.toArray('.reveal').forEach((el, i) => {
    gsap.from(el, { y: 28, opacity: 0, duration: 0.7, ease: 'power3.out', delay: (i % 3) * 0.08, scrollTrigger: { trigger: el, start: 'top 88%', once: true } });
  });
  gsap.from('#heroHost', { y: 40, rotate: -6, opacity: 0, duration: 1, ease: 'back.out(1.6)', delay: 0.3 });
}
