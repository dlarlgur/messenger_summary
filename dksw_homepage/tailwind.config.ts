import type { Config } from 'tailwindcss';

const config: Config = {
  content: ['./src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        ink: {
          950: '#07070A',
          900: '#0A0A0D',
          800: '#101014',
          700: '#16161C',
          600: '#1D1D25',
          500: '#2A2A35',
        },
        fog: {
          100: '#FAFAFA',
          200: '#E6E6EA',
          300: '#B8B8C2',
          400: '#8A8A96',
          500: '#5E5E6C',
        },
        brand: {
          50: '#EFF5FF',
          100: '#DCE8FF',
          200: '#B7D1FF',
          300: '#86B2FF',
          400: '#548BFF',
          500: '#3B82F6',
          600: '#2563EB',
          700: '#1D4ED8',
          800: '#1E40AF',
          900: '#1E3A8A',
        },
      },
      fontFamily: {
        sans: ['var(--font-pretendard)', 'var(--font-geist)', 'system-ui', 'sans-serif'],
        mono: ['var(--font-geist-mono)', 'ui-monospace', 'monospace'],
      },
      fontSize: {
        '2xs': ['0.6875rem', { lineHeight: '1rem' }],
      },
      letterSpacing: {
        tightest: '-0.04em',
      },
      animation: {
        'gradient-shift': 'gradientShift 18s ease-in-out infinite',
        'float-slow': 'float 10s ease-in-out infinite',
        'fade-up': 'fadeUp 0.8s ease-out forwards',
      },
      keyframes: {
        gradientShift: {
          '0%,100%': { transform: 'translate(0,0) scale(1)' },
          '33%': { transform: 'translate(6%, -4%) scale(1.05)' },
          '66%': { transform: 'translate(-5%, 4%) scale(0.98)' },
        },
        float: {
          '0%,100%': { transform: 'translateY(0)' },
          '50%': { transform: 'translateY(-12px)' },
        },
        fadeUp: {
          from: { opacity: '0', transform: 'translateY(20px)' },
          to: { opacity: '1', transform: 'translateY(0)' },
        },
      },
      backgroundImage: {
        'grid-faint':
          'linear-gradient(to right, rgba(255,255,255,0.04) 1px, transparent 1px), linear-gradient(to bottom, rgba(255,255,255,0.04) 1px, transparent 1px)',
        'radial-fade':
          'radial-gradient(ellipse at center, rgba(59,130,246,0.18) 0%, rgba(59,130,246,0) 60%)',
      },
    },
  },
  plugins: [],
};

export default config;
