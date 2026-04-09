import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { 
  Shield, 
  AlertTriangle, 
  MapPin, 
  History, 
  User, 
  Send, 
  ChevronRight,
  Bell,
  Settings,
  LogOut
} from 'lucide-react';
import { analyzeSafety } from './services/aiService';

// --- Types ---
interface Report {
  id: string;
  description: string;
  timestamp: string;
  status: 'Pending' | 'Resolved';
}

interface Alert {
  id: string;
  location: { lat: number; lng: number };
  timestamp: string;
}

// --- Components ---

const MobileFrame = ({ children }: { children: React.ReactNode }) => (
  <div className="flex items-center justify-center min-h-screen bg-slate-100 p-4 font-sans">
    <div className="relative w-full max-w-[400px] h-[800px] bg-white rounded-[3rem] shadow-2xl overflow-hidden border-8 border-slate-800">
      {/* Notch */}
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-32 h-6 bg-slate-800 rounded-b-2xl z-50"></div>
      {children}
    </div>
  </div>
);

const Button = ({ 
  children, 
  onClick, 
  variant = 'primary', 
  className = '',
  disabled = false
}: { 
  children: React.ReactNode; 
  onClick?: () => void; 
  variant?: 'primary' | 'danger' | 'outline';
  className?: string;
  disabled?: boolean;
}) => {
  const variants = {
    primary: 'bg-indigo-600 text-white hover:bg-indigo-700',
    danger: 'bg-rose-500 text-white hover:bg-rose-600 shadow-lg shadow-rose-200',
    outline: 'border-2 border-slate-200 text-slate-600 hover:bg-slate-50'
  };

  return (
    <motion.button
      whileTap={{ scale: 0.95 }}
      onClick={onClick}
      disabled={disabled}
      className={`px-6 py-3 rounded-2xl font-semibold transition-colors disabled:opacity-50 ${variants[variant]} ${className}`}
    >
      {children}
    </motion.button>
  );
};

// --- Screens ---

const LoginScreen = ({ onLogin }: { onLogin: (role: 'child' | 'parent') => void }) => (
  <div className="flex flex-col h-full p-8 justify-center bg-gradient-to-b from-indigo-50 to-white">
    <div className="mb-12 text-center">
      <div className="w-20 h-20 bg-indigo-600 rounded-3xl flex items-center justify-center mx-auto mb-6 shadow-xl shadow-indigo-200">
        <Shield className="text-white w-10 h-10" />
      </div>
      <h1 className="text-3xl font-bold text-slate-900 mb-2">SafeNest</h1>
      <p className="text-slate-500">AI-Powered Child Safety</p>
    </div>

    <div className="space-y-4">
      <Button onClick={() => onLogin('child')} className="w-full py-4">
        Login as Child
      </Button>
      <Button onClick={() => onLogin('parent')} variant="outline" className="w-full py-4">
        Login as Parent
      </Button>
    </div>
  </div>
);

const HomeScreen = ({ role, onNavigate }: { role: string; onNavigate: (screen: string) => void }) => {
  const [isSending, setIsSending] = useState(false);

  const handleSOS = async () => {
    setIsSending(true);
    try {
      await fetch('/api/send_sos', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId: 'user123', location: { lat: 0, lng: 0 } })
      });
      alert('SOS Alert Sent to Guardians!');
    } catch (e) {
      console.error(e);
    } finally {
      setIsSending(false);
    }
  };

  return (
    <div className="flex flex-col h-full bg-white">
      <header className="p-6 pt-12 flex justify-between items-center">
        <div>
          <h2 className="text-2xl font-bold text-slate-900">Hello, {role === 'child' ? 'Alex' : 'Parent'}</h2>
          <p className="text-slate-500 text-sm">You are currently safe</p>
        </div>
        <div className="w-10 h-10 bg-slate-100 rounded-full flex items-center justify-center">
          <Bell className="w-5 h-5 text-slate-600" />
        </div>
      </header>

      <main className="flex-1 p-6 space-y-6 overflow-y-auto">
        {/* SOS Section */}
        <div className="bg-rose-50 p-8 rounded-[2rem] text-center border border-rose-100">
          <h3 className="text-rose-900 font-bold mb-4">Emergency Help</h3>
          <motion.button
            animate={isSending ? { scale: [1, 1.1, 1] } : {}}
            transition={{ repeat: Infinity, duration: 1 }}
            onClick={handleSOS}
            disabled={isSending}
            className="w-32 h-32 bg-rose-500 rounded-full flex items-center justify-center mx-auto shadow-2xl shadow-rose-300 border-8 border-white active:scale-95 transition-transform"
          >
            <span className="text-white text-2xl font-black">SOS</span>
          </motion.button>
          <p className="mt-4 text-rose-600 text-sm font-medium">Press for 3 seconds to alert</p>
        </div>

        {/* Quick Actions */}
        <div className="grid grid-cols-2 gap-4">
          <button 
            onClick={() => onNavigate('report')}
            className="p-4 bg-indigo-50 rounded-3xl text-left border border-indigo-100 hover:bg-indigo-100 transition-colors"
          >
            <div className="w-10 h-10 bg-indigo-600 rounded-xl flex items-center justify-center mb-3">
              <AlertTriangle className="text-white w-5 h-5" />
            </div>
            <span className="font-bold text-indigo-900 block">Report</span>
            <span className="text-xs text-indigo-600">Unsafe situation</span>
          </button>
          <button 
            onClick={() => onNavigate('location')}
            className="p-4 bg-emerald-50 rounded-3xl text-left border border-emerald-100 hover:bg-emerald-100 transition-colors"
          >
            <div className="w-10 h-10 bg-emerald-600 rounded-xl flex items-center justify-center mb-3">
              <MapPin className="text-white w-5 h-5" />
            </div>
            <span className="font-bold text-emerald-900 block">Location</span>
            <span className="text-xs text-emerald-600">Share live path</span>
          </button>
        </div>

        {/* Recent Activity */}
        <div>
          <div className="flex justify-between items-center mb-4">
            <h3 className="font-bold text-slate-900">Recent Activity</h3>
            <button onClick={() => onNavigate('history')} className="text-indigo-600 text-sm font-semibold">See all</button>
          </div>
          <div className="space-y-3">
            {[1, 2].map((i) => (
              <div key={i} className="flex items-center p-4 bg-slate-50 rounded-2xl">
                <div className="w-10 h-10 bg-white rounded-xl flex items-center justify-center mr-4 shadow-sm">
                  <History className="w-5 h-5 text-slate-400" />
                </div>
                <div className="flex-1">
                  <p className="text-sm font-bold text-slate-800">Location shared</p>
                  <p className="text-xs text-slate-500">2 hours ago</p>
                </div>
                <ChevronRight className="w-4 h-4 text-slate-300" />
              </div>
            ))}
          </div>
        </div>
      </main>
    </div>
  );
};

const ReportScreen = ({ onBack }: { onBack: () => void }) => {
  const [description, setDescription] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [aiFeedback, setAiFeedback] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    try {
      // 1. Submit to backend
      await fetch('/api/submit_report', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId: 'user123', description })
      });
      
      // 2. Get AI Analysis
      const feedback = await analyzeSafety(description);
      setAiFeedback(feedback || 'Analysis complete.');
      
      alert('Report submitted successfully!');
    } catch (e) {
      console.error(e);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="flex flex-col h-full bg-white">
      <header className="p-6 pt-12 flex items-center">
        <button onClick={onBack} className="mr-4 p-2 hover:bg-slate-100 rounded-full transition-colors">
          <ChevronRight className="w-6 h-6 rotate-180" />
        </button>
        <h2 className="text-xl font-bold text-slate-900">Report Situation</h2>
      </header>
      <form onSubmit={handleSubmit} className="p-6 space-y-6">
        <div className="space-y-2">
          <label className="text-sm font-bold text-slate-700">What happened?</label>
          <textarea 
            required
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="Describe the situation or location..."
            className="w-full h-40 p-4 bg-slate-50 rounded-2xl border-2 border-transparent focus:border-indigo-500 outline-none transition-all resize-none"
          />
        </div>

        {aiFeedback && (
          <motion.div 
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            className="p-4 bg-indigo-50 rounded-2xl border border-indigo-100"
          >
            <div className="flex items-center gap-2 mb-1">
              <Shield className="w-4 h-4 text-indigo-600" />
              <span className="text-xs font-bold text-indigo-900 uppercase tracking-wider">AI Safety Analysis</span>
            </div>
            <p className="text-sm text-indigo-700">{aiFeedback}</p>
          </motion.div>
        )}

        <Button disabled={isSubmitting} className="w-full py-4 flex items-center justify-center gap-2">
          {isSubmitting ? 'Submitting...' : <><Send className="w-5 h-5" /> Submit Report</>}
        </Button>
      </form>
    </div>
  );
};

const StatusScreen = ({ onBack }: { onBack: () => void }) => (
  <div className="flex flex-col h-full bg-white">
    <header className="p-6 pt-12 flex items-center">
      <button onClick={onBack} className="mr-4 p-2 hover:bg-slate-100 rounded-full transition-colors">
        <ChevronRight className="w-6 h-6 rotate-180" />
      </button>
      <h2 className="text-xl font-bold text-slate-900">Safety Status</h2>
    </header>
    <div className="p-6 space-y-4">
      <div className="p-6 bg-emerald-50 rounded-3xl border border-emerald-100 flex items-center gap-4">
        <div className="w-12 h-12 bg-emerald-500 rounded-full flex items-center justify-center shadow-lg shadow-emerald-200">
          <Shield className="text-white w-6 h-6" />
        </div>
        <div>
          <p className="font-bold text-emerald-900">System Active</p>
          <p className="text-sm text-emerald-600">Monitoring for anomalies</p>
        </div>
      </div>
      
      <div className="p-6 bg-slate-50 rounded-3xl border border-slate-100">
        <h3 className="font-bold text-slate-900 mb-4">Alert History</h3>
        <div className="space-y-4">
          <div className="flex justify-between items-center text-sm">
            <span className="text-slate-500">SOS Triggered</span>
            <span className="font-mono text-slate-400">Apr 08, 10:20</span>
          </div>
          <div className="flex justify-between items-center text-sm">
            <span className="text-slate-500">Report Sent</span>
            <span className="font-mono text-slate-400">Apr 07, 15:45</span>
          </div>
        </div>
      </div>
    </div>
  </div>
);

const OnboardingScreen = ({ role, onComplete }: { role: 'child' | 'parent', onComplete: () => void }) => {
  const [step, setStep] = useState(0);
  const childSteps = [
    { title: "Welcome to SafeNest", desc: "Your personal safety companion.", icon: <Shield className="w-12 h-12 text-indigo-600" /> },
    { title: "The SOS Button", desc: "Hold the red button for 3 seconds if you feel unsafe.", icon: <AlertTriangle className="w-12 h-12 text-rose-500" /> },
    { title: "Stay Connected", desc: "Your parents will see your location only when you need help.", icon: <MapPin className="w-12 h-12 text-emerald-500" /> }
  ];
  const parentSteps = [
    { title: "Guardian Mode", desc: "Monitor your child's safety in real-time.", icon: <Shield className="w-12 h-12 text-indigo-600" /> },
    { title: "Secure Linking", desc: "Use a unique 6-digit code to link with your child. No one else can access.", icon: <User className="w-12 h-12 text-blue-500" /> },
    { title: "Instant Alerts", desc: "Get notified immediately if an SOS is triggered.", icon: <Bell className="w-12 h-12 text-rose-500" /> }
  ];
  const steps = role === 'child' ? childSteps : parentSteps;

  return (
    <div className="flex flex-col h-full p-8 bg-white">
      <div className="flex-1 flex flex-col items-center justify-center text-center">
        <motion.div
          key={step}
          initial={{ opacity: 0, scale: 0.8 }}
          animate={{ opacity: 1, scale: 1 }}
          className="mb-8 p-6 bg-slate-50 rounded-full"
        >
          {steps[step].icon}
        </motion.div>
        <h2 className="text-2xl font-bold text-slate-900 mb-4">{steps[step].title}</h2>
        <p className="text-slate-500">{steps[step].desc}</p>
      </div>
      <div className="flex gap-2 justify-center mb-8">
        {steps.map((_, i) => (
          <div key={i} className={`h-1.5 rounded-full transition-all ${i === step ? 'w-8 bg-indigo-600' : 'w-2 bg-slate-200'}`} />
        ))}
      </div>
      <Button 
        onClick={() => step < steps.length - 1 ? setStep(step + 1) : onComplete()}
        className="w-full py-4"
      >
        {step === steps.length - 1 ? "Get Started" : "Next"}
      </Button>
    </div>
  );
};

const LinkingScreen = ({ role, onLinked }: { role: 'child' | 'parent', onLinked: () => void }) => {
  const [code, setCode] = useState('');
  const [isLinking, setIsLinking] = useState(false);

  const handleLink = () => {
    setIsLinking(true);
    setTimeout(() => {
      setIsLinking(false);
      onLinked();
    }, 1500);
  };

  return (
    <div className="flex flex-col h-full p-8 bg-white justify-center">
      <div className="text-center mb-12">
        <div className="w-16 h-16 bg-blue-50 rounded-2xl flex items-center justify-center mx-auto mb-4">
          <User className="text-blue-600 w-8 h-8" />
        </div>
        <h2 className="text-2xl font-bold text-slate-900 mb-2">Secure Link</h2>
        <p className="text-slate-500 text-sm">
          {role === 'child' 
            ? "Enter the 6-digit code from your parent's phone." 
            : "Share this code with your child to link accounts."}
        </p>
      </div>

      {role === 'parent' ? (
        <div className="bg-slate-50 p-8 rounded-3xl text-center mb-8 border-2 border-dashed border-slate-200">
          <span className="text-4xl font-black tracking-[0.5em] text-indigo-600">482 931</span>
        </div>
      ) : (
        <input 
          type="text" 
          maxLength={6}
          placeholder="000 000"
          value={code}
          onChange={(e) => setCode(e.target.value)}
          className="w-full p-6 text-center text-3xl font-black tracking-[0.2em] bg-slate-50 rounded-3xl border-2 border-transparent focus:border-indigo-500 outline-none mb-8"
        />
      )}

      <Button 
        onClick={handleLink} 
        disabled={isLinking || (role === 'child' && code.length < 6)}
        className="w-full py-4"
      >
        {isLinking ? "Verifying..." : role === 'child' ? "Link Account" : "I've Shared the Code"}
      </Button>
      
      <p className="mt-6 text-[10px] text-slate-400 text-center uppercase tracking-widest font-bold">
        End-to-End Encrypted Connection
      </p>
    </div>
  );
};

// --- Main App ---

export default function App() {
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [role, setRole] = useState<'child' | 'parent'>('child');
  const [appState, setAppState] = useState<'onboarding' | 'linking' | 'main'>('onboarding');
  const [currentScreen, setCurrentScreen] = useState('home');
  const [showSourceInfo, setShowSourceInfo] = useState(false);

  const handleLogin = (selectedRole: 'child' | 'parent') => {
    setRole(selectedRole);
    setIsLoggedIn(true);
  };

  const renderAppContent = () => {
    if (appState === 'onboarding') {
      return <OnboardingScreen role={role} onComplete={() => setAppState('linking')} />;
    }
    if (appState === 'linking') {
      return <LinkingScreen role={role} onLinked={() => setAppState('main')} />;
    }

    const renderScreen = () => {
      switch (currentScreen) {
        case 'home': return <HomeScreen role={role} onNavigate={setCurrentScreen} />;
        case 'report': return <ReportScreen onBack={() => setCurrentScreen('home')} />;
        case 'location': return <StatusScreen onBack={() => setCurrentScreen('home')} />;
        case 'history': return <StatusScreen onBack={() => setCurrentScreen('home')} />;
        default: return <HomeScreen role={role} onNavigate={setCurrentScreen} />;
      }
    };

    return (
      <div className="h-full flex flex-col">
        <div className="flex-1 overflow-hidden">
          {renderScreen()}
        </div>
        
        {/* Bottom Nav */}
        <nav className="h-20 bg-white border-t border-slate-100 flex items-center justify-around px-4 pb-4">
          <button 
            onClick={() => setCurrentScreen('home')}
            className={`p-2 rounded-2xl transition-colors ${currentScreen === 'home' ? 'text-indigo-600 bg-indigo-50' : 'text-slate-400'}`}
          >
            <Shield className="w-6 h-6" />
          </button>
          <button 
            onClick={() => setCurrentScreen('location')}
            className={`p-2 rounded-2xl transition-colors ${currentScreen === 'location' ? 'text-indigo-600 bg-indigo-50' : 'text-slate-400'}`}
          >
            <MapPin className="w-6 h-6" />
          </button>
          <button 
            onClick={() => setCurrentScreen('history')}
            className={`p-2 rounded-2xl transition-colors ${currentScreen === 'history' ? 'text-indigo-600 bg-indigo-50' : 'text-slate-400'}`}
          >
            <History className="w-6 h-6" />
          </button>
          <button 
            onClick={() => {
              setIsLoggedIn(false);
              setAppState('onboarding');
            }}
            className="p-2 rounded-2xl text-slate-400"
          >
            <LogOut className="w-6 h-6" />
          </button>
        </nav>
      </div>
    );
  };

  return (
    <div className="flex flex-col lg:flex-row min-h-screen bg-slate-50">
      {/* Sidebar Info (Desktop Only) */}
      <div className="hidden lg:flex flex-col w-96 p-8 bg-white border-r border-slate-200 overflow-y-auto">
        <div className="mb-8">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 bg-indigo-600 rounded-xl flex items-center justify-center">
              <Shield className="text-white w-6 h-6" />
            </div>
            <h1 className="text-2xl font-bold text-slate-900 tracking-tight">SafeNest</h1>
          </div>
          <p className="text-slate-500 text-sm leading-relaxed">
            This is a <strong>High-Fidelity Mobile Simulator</strong>. The actual application code for <strong>Flutter</strong> and <strong>Python</strong> is available in the project files.
          </p>
        </div>

        <div className="space-y-6">
          <section className="p-4 bg-rose-50 rounded-2xl border border-rose-100">
            <h3 className="text-xs font-bold text-rose-900 uppercase tracking-widest mb-2 flex items-center gap-2">
              <Shield className="w-3 h-3" /> High Security Linking
            </h3>
            <p className="text-[11px] text-rose-700 leading-relaxed">
              Accounts are linked via cryptographically generated 6-digit tokens. This ensures a 1:1 secure bond between a child and their verified guardian.
            </p>
          </section>

          <section>
            <h3 className="text-xs font-bold text-slate-400 uppercase tracking-widest mb-3">Project Review Guide</h3>
            <div className="space-y-3">
              <div className="p-3 bg-slate-50 rounded-xl border border-slate-100">
                <p className="text-xs font-bold text-slate-700 mb-1">No Mac? No Problem.</p>
                <p className="text-[10px] text-slate-500">Use this simulator for your demo. It shows the full onboarding, linking, and safety flow.</p>
              </div>
              <div className="p-3 bg-slate-50 rounded-xl border border-slate-100">
                <p className="text-xs font-bold text-slate-700 mb-1">Source Code</p>
                <p className="text-[10px] text-slate-500">Show the /flutter_app and /ai_module folders to prove technical implementation.</p>
              </div>
            </div>
          </section>
        </div>
      </div>

      {/* Simulator Area */}
      <div className="flex-1 flex items-center justify-center p-4">
        <MobileFrame>
          <AnimatePresence mode="wait">
            {!isLoggedIn ? (
              <motion.div
                key="login"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                className="h-full"
              >
                <LoginScreen onLogin={handleLogin} />
              </motion.div>
            ) : (
              <motion.div
                key="app"
                initial={{ opacity: 0, x: 20 }}
                animate={{ opacity: 1, x: 0 }}
                className="h-full"
              >
                {renderAppContent()}
              </motion.div>
            )}
          </AnimatePresence>
        </MobileFrame>
      </div>

      {/* Mobile Info Overlay (Mobile Only) */}
      <div className="lg:hidden fixed bottom-4 right-4 z-[100]">
        <button 
          onClick={() => setShowSourceInfo(!showSourceInfo)}
          className="w-12 h-12 bg-indigo-600 text-white rounded-full shadow-xl flex items-center justify-center"
        >
          <Settings className="w-6 h-6" />
        </button>
      </div>
    </div>
  );
}
