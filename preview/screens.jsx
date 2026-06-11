// Phone-screen mockups of the redesigned app — "Clay & Ink".
// Static HTML/JSX previews of the new Flutter screens.

const Status = () => (
  <div className="statusbar"><span>9:41</span><span>●●● ⌁ ▮</span></div>
);

const Mark = ({ size = 30 }) => (
  <span className="mark" style={{ width: size, height: size }}><i></i><i></i><i></i><i></i></span>
);

const NavBar = ({ active = 0 }) => {
  const items = [
    ['My Wall', 'M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4zM13 13h7v7h-7z'],
    ['Give', 'M12 20h9M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z'],
    ['Discover', 'M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm4 6-2 6-6 2 2-6z'],
    ['Settings', 'M4 21v-7M4 10V3M12 21v-9M12 8V3M20 21v-5M20 12V3M1 14h6M9 8h6M17 16h6'],
  ];
  return (
    <div className="navbar">
      {items.map(([label, d], i) => (
        <div key={label} className={'item' + (i === active ? ' on' : '')}>
          <span className="ico">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d={d} /></svg>
          </span>
          {label}
        </div>
      ))}
    </div>
  );
};

const Ico = ({ d, color = 'var(--clay)', bg = 'rgba(224,122,95,.13)', size = 40 }) => (
  <span className="tile" style={{ background: bg, width: size, height: size }}>
    <svg className="ic" viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d={d} /></svg>
  </span>
);

const Bar = ({ label, w, score, cls = 'good' }) => (
  <div className="bar-row">
    <span className="lbl">{label}</span>
    <span className="track"><span className="fill" style={{ width: w, display: 'block' }}></span></span>
    <span className={'score ' + cls}>{score}</span>
  </div>
);

// ── 1. Walkthrough ───────────────────────────────────────────────────────────
function ScreenWalkthrough() {
  return (
    <div className="phone">
      <Status />
      <div className="scroll" style={{ gap: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <Mark size={22} />
          <span className="h-display" style={{ fontSize: 14 }}>The Wall</span>
          <span style={{ marginLeft: 'auto', color: 'var(--clay)', fontSize: 11.5, fontWeight: 600 }}>Skip</span>
        </div>
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', gap: 14 }}>
          <div style={{ position: 'relative', width: 130, height: 130, margin: '0 0 10px' }}>
            {[0, 1, 2, 3].map((r) => (
              <div key={r} style={{ position: 'absolute', top: r * 33, left: r % 2 ? -16 : 0, display: 'flex', gap: 5 }}>
                {[0, 1, 2].map((c) => (
                  <span key={c} style={{ width: 44, height: 28, borderRadius: 6, border: '1px solid rgba(56,48,42,.6)' }}></span>
                ))}
              </div>
            ))}
            <span className="tile" style={{ position: 'absolute', inset: 0, margin: 'auto', width: 72, height: 72, background: 'linear-gradient(135deg,var(--ink800),var(--ink850))', border: '1px solid var(--ink700)', boxShadow: '0 10px 30px rgba(224,122,95,.16)' }}>
              <svg className="ic" style={{ width: 30, height: 30 }} viewBox="0 0 24 24" fill="none" stroke="var(--clay)" strokeWidth="2"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7z" /><circle cx="12" cy="12" r="3" /></svg>
            </span>
          </div>
          <div className="kicker">Consent first</div>
          <div className="h-display" style={{ fontSize: 27 }}>You're in control</div>
          <p style={{ color: 'var(--ink300)', fontSize: 13.5, lineHeight: 1.55, margin: 0 }}>
            Everything others write about you stays private until YOU choose what to make public on your wall.
          </p>
        </div>
        <div className="dots" style={{ marginBottom: 16 }}><i></i><i className="on"></i><i></i><i></i></div>
        <div className="btn-primary">Next</div>
      </div>
    </div>
  );
}

// ── 2. Login ─────────────────────────────────────────────────────────────────
function ScreenLogin() {
  return (
    <div className="phone">
      <Status />
      <div className="scroll" style={{ justifyContent: 'center', gap: 0 }}>
        <Mark size={52} />
        <div className="h-display" style={{ fontSize: 30, marginTop: 18 }}>The Wall</div>
        <p style={{ color: 'var(--ink300)', fontSize: 14, lineHeight: 1.45, margin: '8px 0 30px' }}>
          Honest feedback, brick by brick —<br />on your terms.
        </p>
        <div className="card" style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '13px 14px', borderRadius: 13 }}>
          <svg className="ic" viewBox="0 0 24 24" fill="none" stroke="var(--ink400)" strokeWidth="2"><path d="M22 16.9v3a2 2 0 0 1-2.2 2 19.8 19.8 0 0 1-8.6-3 19.5 19.5 0 0 1-6-6 19.8 19.8 0 0 1-3-8.7A2 2 0 0 1 4.1 2h3a2 2 0 0 1 2 1.7c.1 1 .4 2 .7 2.8a2 2 0 0 1-.5 2.1L8.1 9.9a16 16 0 0 0 6 6l1.3-1.2a2 2 0 0 1 2.1-.5c.9.3 1.9.6 2.8.7a2 2 0 0 1 1.7 2z" /></svg>
          <span style={{ color: 'var(--paper)', fontWeight: 600, fontSize: 13 }}>+91</span>
          <span className="muted">Mobile number</span>
        </div>
        <div className="btn-primary" style={{ marginTop: 12 }}>Send OTP</div>
        <p className="muted" style={{ marginTop: 28, fontSize: 10.5, lineHeight: 1.5 }}>
          By continuing you confirm you are 18+ and agree to our consent terms on the next screen.
        </p>
      </div>
    </div>
  );
}

// ── 3. My Wall (locked / soft gate) ─────────────────────────────────────────
function ScreenWallLocked() {
  return (
    <div className="phone">
      <Status />
      <div className="scroll">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
          <div>
            <div className="kicker">Your wall</div>
            <div className="h-display" style={{ fontSize: 24, margin: '4px 0 2px' }}>Hi, Arjun</div>
            <div className="muted">3 bricks laid by people who know you.</div>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 6 }}>
            <Mark size={28} />
            <span className="pill sage">◉ New</span>
          </div>
        </div>
        <div className="card gradient" style={{ padding: 18 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12 }}>
            <Ico size={34} d="M5 11h14v9a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2zM8 11V7a4 4 0 0 1 8 0v4" />
            <span className="h-display" style={{ fontSize: 16 }}>3 people have written about you</span>
          </div>
          <div style={{ display: 'flex', gap: 6, filter: 'blur(5px)', marginBottom: 14 }}>
            {['var(--gold)', 'var(--gold)', 'var(--gold)', 'var(--ink700)', 'var(--ink700)'].map((c, i) => (
              <span key={i} style={{ width: 26, height: 26, borderRadius: 7, background: c }}></span>
            ))}
          </div>
          <div className="kicker" style={{ color: 'var(--ink400)', marginBottom: 7 }}>Lay your first bricks</div>
          <div className="bricks"><i className="f"></i><i className="f"></i><i></i><i></i><i></i></div>
          <p style={{ fontSize: 11.5, color: 'var(--ink300)', margin: '10px 0 0', lineHeight: 1.5 }}>
            Give feedback to 3 more people to open your wall. Honest in, honest out.
          </p>
        </div>
        <div className="card" style={{ display: 'flex', gap: 10, alignItems: 'center', padding: 12 }}>
          <Ico size={32} d="M12 3l8 4v5c0 4.4-3.2 8.1-8 9-4.8-.9-8-4.6-8-9V7l8-4z" />
          <span style={{ fontSize: 11.5, color: 'var(--clay)', fontWeight: 600 }}>Access my data now (privacy right)</span>
        </div>
      </div>
      <NavBar active={0} />
    </div>
  );
}

// ── 4. My Wall (unlocked) ────────────────────────────────────────────────────
function ScreenWallOpen() {
  return (
    <div className="phone">
      <Status />
      <div className="scroll">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
          <div>
            <div className="kicker">Your wall</div>
            <div className="h-display" style={{ fontSize: 24, margin: '4px 0 2px' }}>Hi, Arjun</div>
            <div className="muted">12 bricks laid by people who know you.</div>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 6 }}>
            <Mark size={28} />
            <span className="pill sage">◉ Very open</span>
          </div>
        </div>
        <div className="card">
          <div className="h-display" style={{ fontSize: 15, marginBottom: 4 }}>How people see you</div>
          <Bar label="Punctuality" w="84%" score="4.2" />
          <Bar label="Professionalism" w="92%" score="4.6" />
          <Bar label="Communication" w="68%" score="3.4" cls="mid" />
          <Bar label="Reliability" w="88%" score="4.4" />
        </div>
        <div className="card goldish" style={{ display: 'flex', alignItems: 'center', gap: 11, padding: 13 }}>
          <Ico color="var(--gold-soft)" bg="rgba(217,164,65,.14)" size={34}
            d="M12 15a7 7 0 1 0-7-7c0 2.4 1.2 4.5 3 5.7V17h8v-3.3c1.8-1.2 3-3.3 3-5.7M9 21h6" />
          <div style={{ flex: 1 }}>
            <div style={{ fontWeight: 700, color: 'var(--paper)', fontSize: 12.5 }}>Go deeper with Premium</div>
            <div className="muted" style={{ fontSize: 10.5 }}>Coaching, peer comparison, trends & more.</div>
          </div>
          <span style={{ color: 'var(--gold-soft)' }}>→</span>
        </div>
        <div className="card" style={{ padding: 14 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 9, marginBottom: 9 }}>
            <span className="avatar" style={{ width: 30, height: 30, fontSize: 13 }}>P</span>
            <div style={{ flex: 1 }}>
              <div style={{ fontWeight: 700, color: 'var(--paper)', fontSize: 12 }}>Priya S.</div>
              <div className="muted" style={{ fontSize: 10 }}>Work</div>
            </div>
            <span className="score good">4.5</span>
          </div>
          <div className="chip-row" style={{ marginBottom: 9 }}>
            <span className="chip sel">Great listener</span>
            <span className="chip sel">Follows through</span>
          </div>
          <div className="quote">“Always the calmest person in the room when a deadline slips. I'd want him on every project.”</div>
        </div>
      </div>
      <NavBar active={0} />
    </div>
  );
}

// ── 5. Compose feedback ──────────────────────────────────────────────────────
function ScreenCompose() {
  return (
    <div className="phone">
      <Status />
      <div className="scroll">
        <div className="appbar">
          <span className="back">←</span>
          <span className="title">For Priya</span>
        </div>
        <div className="muted" style={{ fontSize: 11.5 }}>Rate honestly — they'll see patterns, not your individual scores.</div>
        <div className="card" style={{ padding: 13 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 9 }}>
            <span style={{ fontWeight: 700, color: 'var(--paper)', fontSize: 12.5 }}>Punctuality</span>
            <span className="h-display" style={{ fontSize: 13, color: 'var(--clay)' }}>4/5</span>
          </div>
          <div className="rate-bricks"><i className="on">1</i><i className="on">2</i><i className="on">3</i><i className="on top">4</i><i>5</i></div>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 7 }}>
            <span className="muted" style={{ fontSize: 9.5 }}>Often late</span>
            <span className="muted" style={{ fontSize: 9.5 }}>Always on time</span>
          </div>
        </div>
        <div className="card" style={{ padding: 13 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 9 }}>
            <span style={{ fontWeight: 700, color: 'var(--paper)', fontSize: 12.5 }}>Communication</span>
            <span className="h-display" style={{ fontSize: 13, color: 'var(--clay)' }}>5/5</span>
          </div>
          <div className="rate-bricks"><i className="on">1</i><i className="on">2</i><i className="on">3</i><i className="on">4</i><i className="on top">5</i></div>
        </div>
        <div>
          <div className="kicker" style={{ color: 'var(--ink400)', marginBottom: 7 }}>What stands out about them?</div>
          <div className="chip-row">
            <span className="chip sel">Great listener</span>
            <span className="chip">Solution-oriented</span>
            <span className="chip sel">Patient</span>
            <span className="chip">Direct</span>
            <span className="chip">Motivating</span>
          </div>
        </div>
        <div>
          <div className="kicker" style={{ color: 'var(--ink400)', marginBottom: 7 }}>How do you know them?</div>
          <div className="chip-row">
            <span className="chip sel-gold">Work</span>
            <span className="chip">College</span>
            <span className="chip">Client</span>
            <span className="chip">Community</span>
          </div>
        </div>
        <div className="btn-primary">Lay this brick</div>
      </div>
    </div>
  );
}

// ── 6. Brick laid celebration ────────────────────────────────────────────────
function ScreenCelebrate() {
  return (
    <div className="phone" style={{ background: 'rgba(19,16,13,.97)' }}>
      <Status />
      <div className="scroll" style={{ justifyContent: 'center', alignItems: 'center', textAlign: 'center', gap: 0 }}>
        <span className="tile" style={{ width: 78, height: 78, borderRadius: 22, background: 'linear-gradient(135deg,var(--clay-bright),var(--clay-deep))', boxShadow: '0 14px 38px rgba(224,122,95,.45)' }}>
          <svg style={{ width: 38, height: 38 }} viewBox="0 0 24 24" fill="none" stroke="var(--ink950)" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"><path d="M20 6 9 17l-5-5" /></svg>
        </span>
        <div className="h-display" style={{ fontSize: 24, marginTop: 22 }}>Brick laid</div>
        <p style={{ color: 'var(--ink300)', fontSize: 12.5, marginTop: 8 }}>Your feedback is on its way to Priya.</p>
        <p className="muted" style={{ marginTop: 26, fontSize: 10.5 }}>Tap anywhere to continue</p>
      </div>
    </div>
  );
}

// ── 7. Discover ──────────────────────────────────────────────────────────────
function ScreenDiscover() {
  const rows = [
    ['1', 'Meera K.', '482 pts', 'var(--gold)'],
    ['2', 'Rohan D.', '391 pts', '#B8BCC8'],
    ['3', 'Arjun V.', '350 pts', '#C2845A'],
    ['4', 'Sana P.', '297 pts', 'var(--ink400)'],
    ['5', 'Kabir M.', '244 pts', 'var(--ink400)'],
  ];
  return (
    <div className="phone">
      <Status />
      <div className="scroll">
        <div>
          <div className="kicker">Community</div>
          <div className="h-display" style={{ fontSize: 24, margin: '4px 0 4px' }}>Discover</div>
          <div className="muted">We never rank people by their ratings — only by what they give.</div>
        </div>
        <div style={{ display: 'flex', gap: 16, borderBottom: '1px solid var(--ink700)', paddingBottom: 8 }}>
          <span style={{ color: 'var(--paper)', fontWeight: 700, fontSize: 12.5, borderBottom: '2px solid var(--clay)', paddingBottom: 8, marginBottom: -9 }}>Contribution</span>
          <span className="muted" style={{ fontSize: 12.5 }}>Growth</span>
          <span className="muted" style={{ fontSize: 12.5 }}>Openness</span>
        </div>
        {rows.map(([rank, name, val, c], i) => (
          <div className="lb-row" key={rank} style={i < 3 ? { borderColor: c.startsWith('var') ? 'rgba(217,164,65,.4)' : c + '66' } : {}}>
            <span className="rank" style={{ color: c, background: i < 3 ? 'rgba(217,164,65,.10)' : 'var(--ink800)' }}>{rank}</span>
            <span className="name">{name}</span>
            <span className="val">{val}</span>
          </div>
        ))}
      </div>
      <NavBar active={2} />
    </div>
  );
}

// ── 8. Premium ───────────────────────────────────────────────────────────────
function ScreenPremium() {
  return (
    <div className="phone">
      <Status />
      <div className="scroll">
        <div className="appbar"><span className="back">←</span><span className="title">Premium</span></div>
        <div className="card goldish" style={{ padding: 18 }}>
          <Ico color="var(--gold-soft)" bg="rgba(217,164,65,.16)" size={42}
            d="M12 15a7 7 0 1 0-7-7c0 2.4 1.2 4.5 3 5.7V17h8v-3.3c1.8-1.2 3-3.3 3-5.7M9 21h6" />
          <div className="h-display" style={{ fontSize: 21, margin: '12px 0 4px' }}>See the whole picture</div>
          <div style={{ fontSize: 11.5, color: 'var(--ink300)', lineHeight: 1.5 }}>
            Trends, peer comparison, coaching and campaigns — everything to turn feedback into growth.
          </div>
        </div>
        {[
          ['Trend charts', 'See how your scores change over time.', 'M3 17l6-6 4 4 8-8'],
          ['Cohort comparison', 'Where you stand vs. the community.', 'M17 11a4 4 0 1 0-4-4M2 21c0-3.9 3.1-7 7-7s7 3.1 7 7M9 10m-4 0a4 4 0 1 0 8 0a4 4 0 1 0-8 0'],
          ['Coaching prompts', 'Growth tips from your lowest dimensions.', 'M9 18h6M10 21h4M12 3a6 6 0 0 1 3.6 10.8c-.5.4-.6 1-.6 1.7V16h-6v-.5c0-.7-.1-1.3-.6-1.7A6 6 0 0 1 12 3z'],
        ].map(([t, s, d]) => (
          <div key={t} className="card" style={{ display: 'flex', gap: 10, alignItems: 'center', padding: 12 }}>
            <Ico color="var(--gold-soft)" bg="rgba(217,164,65,.12)" size={32} d={d} />
            <div>
              <div style={{ fontWeight: 700, color: 'var(--paper)', fontSize: 12 }}>{t}</div>
              <div className="muted" style={{ fontSize: 10.5 }}>{s}</div>
            </div>
          </div>
        ))}
        <div className="card" style={{ borderColor: 'rgba(217,164,65,.45)', padding: 14 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontWeight: 700, color: 'var(--paper)', fontSize: 12.5 }}>Yearly</span>
            <span style={{ background: 'var(--gold)', color: 'var(--ink950)', borderRadius: 100, fontSize: 8.5, fontWeight: 800, padding: '3px 8px', letterSpacing: '.06em' }}>BEST VALUE</span>
          </div>
          <div className="h-display" style={{ fontSize: 24, color: 'var(--gold-soft)', margin: '6px 0 10px' }}>₹1,999/yr</div>
          <div className="btn-primary" style={{ background: 'var(--gold)', padding: 11 }}>Subscribe yearly</div>
        </div>
      </div>
    </div>
  );
}

// ── 9. Settings ──────────────────────────────────────────────────────────────
function ScreenSettings() {
  const Row = ({ d, t, s, color = 'var(--ink300)' }) => (
    <div style={{ display: 'flex', alignItems: 'center', gap: 11, padding: '11px 13px' }}>
      <svg className="ic" viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d={d} /></svg>
      <div style={{ flex: 1 }}>
        <div style={{ fontWeight: 600, color: color === 'var(--rose)' ? 'var(--rose)' : 'var(--paper)', fontSize: 12 }}>{t}</div>
        {s && <div className="muted" style={{ fontSize: 10 }}>{s}</div>}
      </div>
      <span style={{ color: 'var(--ink600)' }}>›</span>
    </div>
  );
  const Group = ({ children }) => (
    <div style={{ background: 'var(--ink850)', border: '1px solid var(--ink700)', borderRadius: 16, overflow: 'hidden' }}>{children}</div>
  );
  return (
    <div className="phone">
      <Status />
      <div className="scroll">
        <div>
          <div className="kicker">You</div>
          <div className="h-display" style={{ fontSize: 24, marginTop: 4 }}>Settings</div>
        </div>
        <div className="card" style={{ display: 'flex', alignItems: 'center', gap: 12, padding: 13 }}>
          <span className="avatar" style={{ width: 42, height: 42, fontSize: 18 }}>A</span>
          <div style={{ flex: 1 }}>
            <div className="h-display" style={{ fontSize: 15 }}>Arjun</div>
            <div className="muted" style={{ fontSize: 10.5 }}>Free plan</div>
          </div>
          <span style={{ color: 'var(--gold-soft)', fontWeight: 700, fontSize: 12 }}>Upgrade</span>
        </div>
        <div>
          <div className="kicker" style={{ color: 'var(--ink400)', marginBottom: 7 }}>Your privacy · DPDP Act, 2023</div>
          <Group>
            <Row d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3" t="Export my data" s="Download everything we hold about you" />
            <div style={{ height: 1, background: 'var(--ink700)', marginLeft: 44 }}></div>
            <Row d="M12 3l8 4v5c0 4.4-3.2 8.1-8 9-4.8-.9-8-4.6-8-9V7l8-4z" t="Consent & audit log" s="Where your data lives and why" />
            <div style={{ height: 1, background: 'var(--ink700)', marginLeft: 44 }}></div>
            <Row color="var(--rose)" d="M3 6h18M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2m3 0v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6" t="Delete account & data" s="Permanent erasure (right to be forgotten)" />
          </Group>
        </div>
        <div>
          <div className="kicker" style={{ color: 'var(--ink400)', marginBottom: 7 }}>Achievements</div>
          <Group>
            <Row color="var(--gold)" d="M8 21h8M12 17v4M7 4h10v5a5 5 0 0 1-10 0zM7 6H4a3 3 0 0 0 3 5M17 6h3a3 3 0 0 1-3 5" t="Badges & streaks" s="4/10 earned · 6-day streak" />
            <div style={{ height: 1, background: 'var(--ink700)', marginLeft: 44 }}></div>
            <Row color="var(--clay)" d="M3 17l6-6 4 4 8-8M14 7h7v7" t="Trends" s="How your scores change over time" />
          </Group>
        </div>
      </div>
      <NavBar active={3} />
    </div>
  );
}

Object.assign(window, {
  ScreenWalkthrough, ScreenLogin, ScreenWallLocked, ScreenWallOpen,
  ScreenCompose, ScreenCelebrate, ScreenDiscover, ScreenPremium, ScreenSettings,
});
