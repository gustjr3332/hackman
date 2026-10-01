import { useState, type ReactNode } from 'react';
import { signInWithProvider, type SocialProvider } from './api';

const PROVIDERS: { id: SocialProvider; label: string; icon: ReactNode }[] = [
  {
    id: 'kakao',
    label: '카카오로 계속하기',
    icon: (
      <path
        fill="#191919"
        d="M12 3C6.48 3 2 6.58 2 11c0 2.86 1.87 5.37 4.68 6.78l-.95 3.5a.4.4 0 0 0 .61.43L10.5 19.1c.5.06 1 .1 1.5.1 5.52 0 10-3.58 10-8S17.52 3 12 3z"
      />
    ),
  },
  {
    id: 'google',
    label: 'Google로 계속하기',
    icon: (
      <>
        <path fill="#4285F4" d="M22.5 12.27c0-.79-.07-1.54-.2-2.27H12v4.51h5.9a5.04 5.04 0 0 1-2.19 3.31v2.75h3.54c2.07-1.91 3.25-4.72 3.25-8.3z" />
        <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.54-2.75c-.98.66-2.23 1.06-3.74 1.06-2.87 0-5.3-1.94-6.17-4.55H2.17v2.84A11 11 0 0 0 12 23z" />
        <path fill="#FBBC05" d="M5.83 14.1A6.6 6.6 0 0 1 5.49 12c0-.73.13-1.44.34-2.1V7.06H2.17A11 11 0 0 0 1 12c0 1.78.43 3.46 1.17 4.94l3.66-2.84z" />
        <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1A11 11 0 0 0 2.17 7.06l3.66 2.84C6.7 7.32 9.13 5.38 12 5.38z" />
      </>
    ),
  },
  {
    id: 'github',
    label: 'GitHub로 계속하기',
    icon: (
      <path
        fill="currentColor"
        d="M12 .5a11.5 11.5 0 0 0-3.64 22.41c.58.1.79-.25.79-.56v-2c-3.2.7-3.88-1.37-3.88-1.37-.52-1.33-1.28-1.68-1.28-1.68-1.04-.71.08-.7.08-.7 1.15.08 1.76 1.18 1.76 1.18 1.03 1.76 2.69 1.25 3.35.96.1-.74.4-1.25.73-1.54-2.55-.29-5.23-1.28-5.23-5.68 0-1.25.45-2.28 1.18-3.08-.12-.29-.51-1.46.11-3.04 0 0 .96-.31 3.15 1.18a10.9 10.9 0 0 1 5.74 0c2.19-1.49 3.15-1.18 3.15-1.18.62 1.58.23 2.75.11 3.04.74.8 1.18 1.83 1.18 3.08 0 4.41-2.69 5.38-5.25 5.67.41.36.78 1.06.78 2.14v3.17c0 .31.21.67.8.56A11.5 11.5 0 0 0 12 .5z"
      />
    ),
  },
];

export function AuthPanel() {
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  async function handleSocial(provider: SocialProvider) {
    setError('');
    setBusy(true);
    try {
      await signInWithProvider(provider);
    } catch (err) {
      setError(err instanceof Error ? err.message : '소셜 로그인에 실패했습니다');
      setBusy(false);
    }
  }

  return (
    <div className="auth-panel">
      <div className="social-login">
        {PROVIDERS.map((p) => (
          <button key={p.id} type="button" className={`social-${p.id}`} onClick={() => handleSocial(p.id)} disabled={busy}>
            <svg viewBox="0 0 24 24" width="20" height="20" aria-hidden="true">
              {p.icon}
            </svg>
            {p.label}
          </button>
        ))}
      </div>

      {error && <p className="form-error">{error}</p>}

      <p className="auth-footnote">
        처음이면 자동으로 가입됩니다. 계속하면 <a href="/terms.html">이용약관</a>과{' '}
        <a href="/privacy.html">개인정보처리방침</a>에 동의하는 것으로 봅니다. 만 14세 이상만 가입할 수
        있습니다.
      </p>
      <p className="auth-footnote">
        가입한 계정은 참가자이고, 심사위원은 운영자가 배정하며 운영자 권한은 관리자가 부여합니다.
        대회 목록과 스코어보드는 로그인 없이 볼 수 있습니다.
      </p>
    </div>
  );
}
