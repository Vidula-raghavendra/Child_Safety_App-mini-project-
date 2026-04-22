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
  LogOut,
  ArrowLeft,
  CheckCircle2,
  Lock,
  Loader2
} from 'lucide-react';
import { processReportSafety } from './services/safetyService';
import { auth, db, signInWithGoogle } from './lib/firebase';
import { onAuthStateChanged, User as FirebaseUser } from 'firebase/auth';
import { 
  doc, 
  getDoc, 
  setDoc, 
  updateDoc, 
  collection, 
  addDoc, 
  query, 
  where, 
  getDocs,
  onSnapshot, 
  orderBy, 
  limit,
  Timestamp,
  serverTimestamp
} from 'firebase/firestore';
import { handleFirestoreError } from './lib/errorHandlers';

// --- Types ---

interface UserProfile {
  uid: string;
  email: string;
  role: 'child' | 'parent';
  linkedUid?: string;
  linkingCode?: string;
  displayName: string;
  createdAt: Timestamp;
  lastKnownLocation?: { lat: number; lng: number };
  locationUpdatedAt?: Timestamp;
}

interface SafetyReport {
  id: string;
  childUid: string;
  parentUid: string;
  description: string;
  safetyFeedback?: string;
  status: 'pending' | 'reviewed';
  createdAt: Timestamp;
}

interface SOSAlert {
  id: string;
  childUid: string;
  parentUid: string;
  location: { lat: number; lng: number };
  status: 'active' | 'resolved';
  createdAt: Timestamp;
}

// --- Hooks ---

const useLocationSharing = (profile: UserProfile | null) => {
  const [linkedProfile, setLinkedProfile] = useState<UserProfile | null>(null);

  useEffect(() => {
    if (!profile) return;

    // Broadcasting logic for children
    let watchId: number | null = null;
    if (profile.role === 'child') {
      if ("geolocation" in navigator) {
        watchId = navigator.geolocation.watchPosition(
          async (position) => {
            const { latitude, longitude } = position.coords;
            try {
              await updateDoc(doc(db, 'users', profile.uid), {
                lastKnownLocation: { lat: latitude, lng: longitude },
                locationUpdatedAt: serverTimestamp()
              });
            } catch (err) {
              console.error("Failed to update location", err);
            }
          },
          (error) => console.error("Location error", error),
          { enableHighAccuracy: true, timeout: 10000, maximumAge: 60000 }
        );
      }
    }

    // Listening logic for parents to see their child
    let unsubscribe: (() => void) | null = null;
    if (profile.linkedUid) {
      unsubscribe = onSnapshot(doc(db, 'users', profile.linkedUid), (snap) => {
        if (snap.exists()) {
          setLinkedProfile({ ...snap.data(), uid: snap.id } as UserProfile);
        }
      });
    }

    return () => {
      if (watchId !== null) navigator.geolocation.clearWatch(watchId);
      if (unsubscribe) unsubscribe();
    };
  }, [profile?.uid, profile?.role, profile?.linkedUid]);

  return linkedProfile;
};

// --- Components ---

const MobileFrame = ({ children }: { children: React.ReactNode }) => (
  <div className="flex items-center justify-center min-h-screen bg-slate-100 p-4 font-sans select-none">
    <div className="relative w-full max-w-[400px] h-[860px] bg-slate-900 rounded-[4rem] p-3 shadow-ios-heavy border-[12px] border-slate-900 group">
      {/* Side Buttons */}
      <div className="absolute left-[-14px] top-32 w-[3px] h-16 bg-slate-800 rounded-l-md" />
      <div className="absolute left-[-14px] top-52 w-[3px] h-12 bg-slate-800 rounded-l-md" />
      <div className="absolute left-[-14px] top-66 w-[3px] h-12 bg-slate-800 rounded-l-md" />
      <div className="absolute right-[-14px] top-40 w-[3px] h-24 bg-slate-800 rounded-r-md" />

      <div className="relative w-full h-full bg-white rounded-[3rem] overflow-hidden">
        {/* Notch Area */}
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-40 h-8 bg-slate-900 rounded-b-[1.75rem] z-50 flex items-center justify-between px-6">
          <div className="w-10 h-1 bg-slate-800 rounded-full" />
          <div className="w-2 h-2 bg-slate-800 rounded-full" />
        </div>
        
        {/* Status Bar */}
        <div className="absolute top-0 w-full h-8 px-8 flex justify-between items-center text-[10px] font-bold text-slate-400 z-40">
          <span>9:41</span>
          <div className="flex gap-1.5 items-center">
            <div className="w-4 h-2 bg-slate-200 rounded-[2px]" />
            <div className="w-2 h-2 rounded-full border-2 border-slate-200" />
          </div>
        </div>
        {children}
      </div>
    </div>
  </div>
);

const Button = ({ 
  children, 
  onClick, 
  variant = 'primary', 
  className = '',
  disabled = false,
  size = 'md'
}: { 
  children: React.ReactNode; 
  onClick?: () => void; 
  variant?: 'primary' | 'danger' | 'outline' | 'ghost';
  className?: string;
  disabled?: boolean;
  size?: 'sm' | 'md' | 'lg';
}) => {
  const variants = {
    primary: 'bg-indigo-600 text-white hover:bg-indigo-700 shadow-lg shadow-indigo-200 active:shadow-none',
    danger: 'bg-rose-600 text-white hover:bg-rose-700 shadow-lg shadow-rose-200 active:shadow-none',
    outline: 'border-2 border-slate-200 text-slate-600 hover:bg-slate-50 hover:border-slate-300',
    ghost: 'text-slate-500 hover:bg-slate-100'
  };

  const sizes = {
    sm: 'px-4 py-2 text-sm rounded-xl',
    md: 'px-6 py-4 rounded-2xl',
    lg: 'px-8 py-5 text-lg rounded-3xl font-bold'
  };

  return (
    <motion.button
      whileTap={{ scale: 0.98 }}
      onClick={onClick}
      disabled={disabled}
      className={`font-semibold transition-all duration-200 disabled:opacity-50 flex items-center justify-center gap-2 ${variants[variant]} ${sizes[size]} ${className}`}
    >
      {children}
    </motion.button>
  );
};

// --- Screens ---

const LandingPage = ({ onStart }: { onStart: () => void }) => {
  return (
    <div className="flex flex-col h-full bg-white overflow-hidden selection:bg-indigo-100">
      {/* Hero Image Section */}
      <div className="relative h-[45%] overflow-hidden">
        <motion.img 
          initial={{ scale: 1.2, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          transition={{ duration: 1.5, ease: "easeOut" }}
          src="https://picsum.photos/seed/safenest_family/800/1200" 
          alt="Safety first"
          className="w-full h-full object-cover"
          referrerPolicy="no-referrer"
        />
        <div className="absolute inset-0 bg-gradient-to-t from-white via-white/20 to-transparent" />
        
        {/* Floating Badge */}
        <motion.div 
          initial={{ x: 20, opacity: 0 }}
          animate={{ x: 0, opacity: 1 }}
          transition={{ delay: 0.8 }}
          className="absolute bottom-10 right-8 p-4 bg-white/90 backdrop-blur-md rounded-2xl ios-shadow border border-white/50 flex items-center gap-3"
        >
          <div className="w-10 h-10 bg-emerald-500 rounded-xl flex items-center justify-center">
            <Shield className="text-white w-6 h-6" />
          </div>
          <div>
            <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">System Status</p>
            <p className="text-sm font-bold text-slate-900">Secure & Online</p>
          </div>
        </motion.div>
      </div>

      {/* Content Section */}
      <div className="flex-1 px-10 pb-12 flex flex-col justify-between">
        <div className="space-y-6">
          <motion.div
            initial={{ y: 20, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            transition={{ delay: 0.3 }}
          >
            <h1 className="text-5xl font-display font-extrabold text-slate-900 leading-[0.9] tracking-tighter mb-4">
              Family Safety,<br/>
              <span className="text-indigo-600">Redefined.</span>
            </h1>
            <p className="text-slate-500 text-lg leading-relaxed max-w-[280px]">
              The smart guardian in your pocket. Trusted by over 50,000 families worldwide.
            </p>
          </motion.div>

          <motion.div 
            initial={{ y: 20, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            transition={{ delay: 0.5 }}
            className="flex flex-wrap gap-3"
          >
            {["24/7 Monitoring", "Secure Sync", "SOS Direct"].map((tag, i) => (
              <span key={i} className="px-4 py-2 bg-slate-50 text-slate-400 text-[10px] font-bold uppercase tracking-widest rounded-full border border-slate-100">
                {tag}
              </span>
            ))}
          </motion.div>
        </div>

        <motion.div
          initial={{ y: 20, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ delay: 0.7 }}
        >
          <Button onClick={onStart} size="lg" className="w-full group">
            Get Started <ChevronRight className="w-5 h-5 group-hover:translate-x-1 transition-transform" />
          </Button>
          <p className="text-center mt-6 text-xs text-slate-400 font-medium">
            By continuing, you agree to our <span className="text-indigo-600">Terms of Service</span>.
          </p>
        </motion.div>
      </div>
    </div>
  );
};

const LoginScreen = ({ onLogin }: { onLogin: (profile: UserProfile) => void }) => {
  const [loading, setLoading] = useState(false);

  const handleAuth = async (role: 'child' | 'parent') => {
    setLoading(true);
    let authenticatedUser: FirebaseUser | null = null;
    try {
      const result = await signInWithGoogle();
      authenticatedUser = result.user;
      
      // Check if profile exists
      const userDoc = await getDoc(doc(db, 'users', authenticatedUser.uid));
      let profileData: UserProfile;

      if (!userDoc.exists()) {
        // Create initial profile
        const newProfile: Partial<UserProfile> = {
          uid: authenticatedUser.uid,
          email: authenticatedUser.email || '',
          role: role,
          displayName: authenticatedUser.displayName || 'User',
          createdAt: serverTimestamp() as any
        };
        await setDoc(doc(db, 'users', authenticatedUser.uid), newProfile);
        profileData = { ...newProfile, id: authenticatedUser.uid } as any;
      } else {
        profileData = userDoc.data() as UserProfile;
      }
      onLogin(profileData);
    } catch (error) {
      console.error('Login error:', error);
      handleFirestoreError(error, 'write', authenticatedUser ? `users/${authenticatedUser.uid}` : 'auth/users', auth);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex flex-col h-full p-10 justify-between bg-white text-center">
      <div className="mt-20">
        <motion.div 
          initial={{ y: 20, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          className="w-24 h-24 bg-indigo-600 rounded-[2rem] flex items-center justify-center mx-auto mb-8 ios-shadow"
        >
          <Shield className="text-white w-12 h-12" />
        </motion.div>
        <motion.h1 
          initial={{ y: 20, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ delay: 0.1 }}
          className="text-4xl font-display font-bold text-slate-900 mb-3 tracking-tight"
        >
          SafeNest
        </motion.h1>
        <motion.p 
          initial={{ y: 20, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ delay: 0.2 }}
          className="text-slate-500 text-lg"
        >
          Your family's safety, <br /> simplified and secure.
        </motion.p>
      </div>

      <motion.div 
        initial={{ y: 20, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ delay: 0.3 }}
        className="space-y-4 mb-10"
      >
        <Button onClick={() => handleAuth('child')} disabled={loading} size="lg" className="w-full">
          {loading ? <Loader2 className="w-5 h-5 animate-spin" /> : "I'm a Child"}
        </Button>
        <Button onClick={() => handleAuth('parent')} disabled={loading} variant="outline" size="lg" className="w-full">
          {loading ? <Loader2 className="w-5 h-5 animate-spin" /> : "I'm a Parent"}
        </Button>
      </motion.div>
    </div>
  );
};

const OnboardingScreen = ({ role, onComplete }: { role: 'child' | 'parent', onComplete: () => void }) => {
  const [step, setStep] = useState(0);
  const childSteps = [
    { title: "Always Protected", desc: "SafeNest keeps a watchful eye on your surroundings while you explore.", image: "https://picsum.photos/seed/safe_child1/600/800" },
    { title: "SOS in a Tap", desc: "Hold the red button if you feel unsafe. We'll alert your parents instantly.", image: "https://picsum.photos/seed/safe_child2/600/800" },
    { title: "Smart Sharing", desc: "Your location is shared securely only with people you trust.", image: "https://picsum.photos/seed/safe_child3/600/800" }
  ];
  const parentSteps = [
    { title: "Guardian Mode", desc: "Real-time insights into your child's safety and surroundings.", image: "https://picsum.photos/seed/parent1/600/800" },
    { title: "Secure Linking", desc: "A private, encrypted bond between you and your child.", image: "https://picsum.photos/seed/parent2/600/800" },
    { title: "Safety Alerts", desc: "Get instant risk assessments on any reported situations.", image: "https://picsum.photos/seed/parent3/600/800" }
  ];
  const steps = role === 'child' ? childSteps : parentSteps;

  return (
    <div className="flex flex-col h-full bg-white">
      <div className="relative h-[55%] overflow-hidden">
        <AnimatePresence mode="wait">
          <motion.img
            key={step}
            initial={{ scale: 1.2, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            exit={{ scale: 1.1, opacity: 0 }}
            transition={{ duration: 0.8 }}
            src={steps[step].image}
            alt={steps[step].title}
            className="w-full h-full object-cover"
            referrerPolicy="no-referrer"
          />
        </AnimatePresence>
        <div className="absolute inset-0 bg-gradient-to-t from-white via-white/10 to-transparent" />
      </div>

      <div className="flex-1 flex flex-col items-center text-center px-10 py-6">
        <div className="flex gap-1.5 justify-center mb-6">
          {steps.map((_, i) => (
            <div key={i} className={`h-1.5 rounded-full transition-all duration-300 ${i === step ? 'w-8 bg-indigo-600' : 'w-2 bg-slate-200'}`} />
          ))}
        </div>

        <motion.div
          key={`content-${step}`}
          initial={{ y: 20, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ delay: 0.2 }}
        >
          <h2 className="text-3xl font-display font-bold text-slate-900 mb-3 tracking-tight">
            {steps[step].title}
          </h2>
          <p className="text-slate-500 text-lg leading-relaxed">
            {steps[step].desc}
          </p>
        </motion.div>
      </div>
      
      <div className="px-10 pb-12">
        <Button 
          onClick={() => step < steps.length - 1 ? setStep(step + 1) : onComplete()}
          size="lg"
          className="w-full"
        >
          {step === steps.length - 1 ? "Start Now" : "Next Step"}
        </Button>
      </div>
    </div>
  );
};

const LinkingScreen = ({ user, onLinked }: { user: UserProfile, onLinked: () => void }) => {
  const [inputCode, setInputCode] = useState('');
  const [generatedCode, setGeneratedCode] = useState(user.linkingCode || '');
  const [isProcessing, setIsProcessing] = useState(false);
  const [status, setStatus] = useState<string>('');

  // Listener for real-time linking updates
  useEffect(() => {
    const unsubscribe = onSnapshot(doc(db, 'users', user.uid), (snap) => {
      if (snap.exists()) {
        const data = snap.data() as UserProfile;
        if (data.linkedUid) {
          onLinked();
        }
        if (data.linkingCode) {
          setGeneratedCode(data.linkingCode);
        }
      }
    });
    return () => unsubscribe();
  }, [user.uid, onLinked]);

  const handleGenerateCode = async () => {
    setIsProcessing(true);
    setStatus('');
    const newCode = Math.floor(100000 + Math.random() * 900000).toString();
    try {
      await updateDoc(doc(db, 'users', user.uid), {
        linkingCode: newCode
      });
      setGeneratedCode(newCode);
    } catch (e) {
      console.error(e);
      setStatus("Failed to generate code");
    } finally {
      setIsProcessing(false);
    }
  };

  const handleLink = async () => {
    if (user.role === 'parent') {
      if (!generatedCode) {
        handleGenerateCode();
      } else {
        setStatus("Waiting for child to enter the code...");
      }
      return;
    }

    // Child linking logic
    setIsProcessing(true);
    setStatus('');
    try {
      const q = query(
        collection(db, 'users'),
        where('role', '==', 'parent'),
        where('linkingCode', '==', inputCode),
        limit(1)
      );
      
      const querySnapshot = await getDocs(q);
      
      if (querySnapshot.empty) {
        setStatus("Invalid or expired code");
        setIsProcessing(false);
        return;
      }
      
      const parentDoc = querySnapshot.docs[0];
      const parentUid = parentDoc.id;
      
      // Update both documents via the rules we just defined
      // We do parent first because our rules allow the child to update the parent if code matches
      await updateDoc(doc(db, 'users', parentUid), {
        linkedUid: user.uid,
        linkingCode: "" // One-time use
      });
      
      await updateDoc(doc(db, 'users', user.uid), {
        linkedUid: parentUid
      });
      
      // The onSnapshot will trigger navigation once linking is synced
    } catch (e) {
      console.error(e);
      setStatus("Link failed. Check connection.");
    } finally {
      setIsProcessing(false);
    }
  };

  return (
    <div className="flex flex-col h-full p-10 bg-white justify-between">
      <div className="mt-12 text-center">
        <div className="w-20 h-20 bg-indigo-50 rounded-3xl flex items-center justify-center mx-auto mb-6">
          <Lock className="text-indigo-600 w-10 h-10" />
        </div>
        <h2 className="text-3xl font-display font-bold text-slate-900 mb-3 tracking-tight leading-tight">Secure Link</h2>
        <p className="text-slate-500 text-lg leading-relaxed px-4">
          {user.role === 'child' 
            ? "Enter the 6-digit code from your parent's device to securely pair." 
            : "Generate a unique code for your child to establish a secure safety link."}
        </p>
      </div>

      <div className="flex-1 flex flex-col justify-center">
        {user.role === 'parent' ? (
          <div className="space-y-6">
            <div className="bg-slate-50 p-10 rounded-[2.5rem] text-center border-2 border-dashed border-slate-200">
              {generatedCode ? (
                <span className="text-5xl font-mono font-bold tracking-[0.2em] text-indigo-600">{generatedCode}</span>
              ) : (
                <span className="text-2xl font-bold text-slate-300">------</span>
              )}
            </div>
            {status && <p className="text-center text-sm font-medium text-indigo-600 animate-pulse">{status}</p>}
          </div>
        ) : (
          <div className="space-y-6">
            <input 
              type="text" 
              maxLength={6}
              placeholder="000000"
              value={inputCode}
              onChange={(e) => setInputCode(e.target.value.replace(/\D/g, ''))}
              className="w-full p-8 text-center text-5xl font-mono font-bold tracking-[0.2em] bg-slate-50 rounded-[2.5rem] border-2 border-transparent focus:border-indigo-500 outline-none transition-all placeholder:text-slate-200"
            />
            {status && <p className="text-center text-sm font-medium text-rose-600">{status}</p>}
          </div>
        )}
      </div>

      <div className="mb-6 space-y-4">
        {user.role === 'parent' && !generatedCode && (
          <Button 
            onClick={handleGenerateCode} 
            disabled={isProcessing}
            size="lg"
            className="w-full"
          >
            {isProcessing ? <Loader2 className="w-5 h-5 animate-spin" /> : "Generate Link Code"}
          </Button>
        )}
        
        {(user.role === 'child' || (user.role === 'parent' && generatedCode)) && (
          <Button 
            onClick={handleLink} 
            disabled={isProcessing || (user.role === 'child' && inputCode.length < 6)}
            size="lg"
            className="w-full"
          >
            {isProcessing ? (
              <Loader2 className="w-5 h-5 animate-spin" />
            ) : user.role === 'child' ? (
              "Pair Accounts"
            ) : (
              "Waiting for Sync..."
            )}
          </Button>
        )}

        <p className="text-[10px] text-slate-400 text-center uppercase tracking-[0.2em] font-bold flex items-center justify-center gap-2">
          <Shield className="w-3 h-3" /> Encrypted Handshake Active
        </p>
      </div>
    </div>
  );
};

const SOSButton = ({ onTrigger }: { onTrigger: () => void }) => {
  const [isPressing, setIsPressing] = useState(false);
  const [progress, setProgress] = useState(0);

  // Trigger SOS when progress hits 100
  useEffect(() => {
    if (progress >= 100) {
      onTrigger();
      setProgress(0);
      setIsPressing(false);
    }
  }, [progress, onTrigger]);

  useEffect(() => {
    let interval: any;
    if (isPressing && progress < 100) {
      interval = setInterval(() => {
        setProgress(prev => Math.min(prev + 2, 100));
      }, 20);
    } else if (!isPressing) {
      setProgress(0);
    }
    return () => clearInterval(interval);
  }, [isPressing, progress]);

  return (
    <div className="relative flex flex-col items-center">
      <div className="absolute inset-0 bg-rose-200 rounded-full blur-[60px] opacity-30 animate-pulse"></div>
      <motion.button
        onMouseDown={() => setIsPressing(true)}
        onMouseUp={() => setIsPressing(false)}
        onMouseLeave={() => setIsPressing(false)}
        onTouchStart={() => setIsPressing(true)}
        onTouchEnd={() => setIsPressing(false)}
        className="relative w-56 h-56 rounded-full bg-rose-600 flex items-center justify-center ios-shadow-heavy sos-glow active:scale-95 transition-transform overflow-hidden border-8 border-white/20"
      >
        {/* Progress Fill */}
        <motion.div 
          className="absolute bottom-0 left-0 w-full bg-rose-800"
          initial={{ height: 0 }}
          animate={{ height: `${progress}%` }}
        />
        
        <div className="relative z-10 flex flex-col items-center">
          <span className="text-white text-6xl font-black tracking-tighter mb-1">SOS</span>
          <span className="text-rose-100 text-[11px] font-bold uppercase tracking-[0.2em]">Hold 2s to alert</span>
        </div>
      </motion.button>
      
      <AnimatePresence>
        {isPressing && (
          <motion.p 
            initial={{ opacity: 0, scale: 0.9, y: 10 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.9, y: 10 }}
            className="mt-8 text-rose-600 font-black text-xs uppercase tracking-[0.3em] bg-rose-50 px-6 py-2 rounded-full border border-rose-100"
          >
            Alerting in {Math.ceil((100 - progress) / 50 * 10) / 10}s
          </motion.p>
        )}
      </AnimatePresence>
    </div>
  );
};

const HomeScreen = ({ profile, linkedProfile, onNavigate }: { profile: UserProfile; linkedProfile: UserProfile | null; onNavigate: (screen: string) => void }) => {
  const [isSending, setIsSending] = useState(false);
  const [lastUpdate, setLastUpdate] = useState("Just now");

  const handleSOS = async () => {
    setIsSending(true);
    try {
      // Get current location for the SOS alert if possible
      let location = { lat: 0, lng: 0 };
      if ("geolocation" in navigator) {
        const pos = await new Promise<GeolocationPosition>((res, rej) => navigator.geolocation.getCurrentPosition(res, rej));
        location = { lat: pos.coords.latitude, lng: pos.coords.longitude };
      }

      await addDoc(collection(db, 'sos_alerts'), {
        childUid: profile.uid,
        parentUid: profile.linkedUid || 'parent_demo_uid',
        location: location,
        status: 'active',
        createdAt: serverTimestamp()
      });
      alert("SOS Alert Sent!");
    } catch (e) {
      handleFirestoreError(e, 'create', '/sos_alerts', auth);
    } finally {
      setIsSending(false);
    }
  };

  return (
    <div className="flex flex-col h-full bg-slate-50 selection:bg-indigo-100">
      <header className="px-8 pt-16 pb-6 flex justify-between items-center">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-full bg-slate-200 overflow-hidden ios-shadow">
            <img src={`https://picsum.photos/seed/${profile.uid}/100/100`} alt="Avatar" referrerPolicy="no-referrer" />
          </div>
          <div>
            <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest leading-none mb-1">
              {profile.role === 'parent' ? 'Guardian Mode' : 'Protected Mode'}
            </p>
            <h2 className="text-xl font-display font-bold text-slate-900 tracking-tight leading-none">
              Hi, {profile.displayName.split(' ')[0]}
            </h2>
          </div>
        </div>
        <button className="w-10 h-10 bg-white rounded-xl flex items-center justify-center ios-shadow text-slate-400 hover:text-indigo-600 transition-colors">
          <Bell className="w-5 h-5" />
        </button>
      </header>

      <main className="flex-1 px-8 space-y-6 overflow-y-auto pb-10 hide-scrollbar">
        {/* Status Card / Map Area */}
        <div className="relative h-64 rounded-[2.5rem] overflow-hidden ios-shadow group">
          <img 
            src="https://picsum.photos/seed/safety_map_hd/600/400" 
            className="w-full h-full object-cover transition-transform duration-700 group-hover:scale-105" 
            alt="Safety Status"
            referrerPolicy="no-referrer"
          />
          <div className="absolute inset-0 bg-gradient-to-t from-slate-900/80 via-slate-900/20 to-transparent" />
          
          {/* Location Ping Marker (If Parent and linkedProfile has location) */}
          {profile.role === 'parent' && linkedProfile?.lastKnownLocation && (
            <motion.div 
              initial={{ scale: 0 }}
              animate={{ scale: 1 }}
              className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 flex flex-col items-center"
            >
              <div className="relative w-12 h-12">
                <div className="absolute inset-0 bg-indigo-500 rounded-full animate-ping opacity-25" />
                <div className="relative w-12 h-12 bg-white rounded-full flex items-center justify-center shadow-2xl border-4 border-indigo-500">
                  <img 
                    src={`https://picsum.photos/seed/${linkedProfile.uid}/40/40`} 
                    className="w-8 h-8 rounded-full" 
                    alt="Child" 
                  />
                </div>
              </div>
              <div className="mt-2 px-3 py-1 bg-white rounded-full shadow-lg border border-slate-100">
                <p className="text-[10px] font-bold text-slate-900 whitespace-nowrap">
                  {linkedProfile.displayName.split(' ')[0]}'s Location
                </p>
              </div>
            </motion.div>
          )}

          <div className="absolute inset-x-0 bottom-0 p-8 flex justify-between items-end">
            <div>
              <p className="text-white/80 text-[10px] font-black uppercase tracking-[0.2em] mb-1">Current Status</p>
              <h3 className="text-white text-3xl font-display font-bold tracking-tight">
                {profile.role === 'parent' 
                  ? (linkedProfile ? 'Monitoring' : 'Disconnected')
                  : 'Protected'
                }
              </h3>
            </div>
            {profile.role === 'child' && (
              <div className="px-3 py-1.5 bg-emerald-500/20 backdrop-blur-md rounded-full border border-emerald-500/30 flex items-center gap-2">
                <div className="w-2 h-2 bg-emerald-400 rounded-full animate-pulse" />
                <span className="text-[10px] font-bold text-white uppercase tracking-widest">Share On</span>
              </div>
            )}
          </div>
        </div>

        {/* SOS Area / Stats */}
        <div className="py-2 flex justify-center">
          {profile.role === 'child' ? (
            <SOSButton onTrigger={handleSOS} />
          ) : (
            <div className="w-full grid grid-cols-1 gap-4">
              <div className="bg-white p-6 rounded-[2rem] ios-shadow flex items-center gap-5 card-hover">
                <div className="w-12 h-12 bg-indigo-50 rounded-2xl flex items-center justify-center">
                  <MapPin className="text-indigo-600 w-6 h-6" />
                </div>
                <div>
                  <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-1">Last Sync</p>
                  <p className="font-bold text-slate-900">
                    {linkedProfile?.locationUpdatedAt 
                      ? `${linkedProfile.locationUpdatedAt.toDate().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}` 
                      : 'Connecting...'
                    }
                  </p>
                </div>
                <div className="ml-auto">
                  <div className={`w-3 h-3 rounded-full ${linkedProfile?.lastKnownLocation ? 'bg-emerald-500' : 'bg-slate-200'} animate-pulse`} />
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Quick Actions Grid */}
        <div className="grid grid-cols-2 gap-4">
          <button 
            onClick={() => onNavigate('report')}
            className="p-6 bg-white rounded-3xl text-left ios-shadow card-hover group relative overflow-hidden"
          >
            <div className="absolute top-0 right-0 w-16 h-16 bg-rose-50 rounded-full blur-2xl translate-x-1/2 -translate-y-1/2" />
            <div className="w-12 h-12 bg-rose-50 rounded-2xl flex items-center justify-center mb-4 group-hover:bg-rose-600 transition-colors z-10 relative">
              <AlertTriangle className="text-rose-600 w-6 h-6 group-hover:text-white transition-colors" />
            </div>
            <p className="font-bold text-slate-900 mb-1 z-10 relative">Emergency Report</p>
            <p className="text-[11px] text-slate-500 leading-tight font-medium opacity-80 z-10 relative">Direct channel to guardian</p>
          </button>
          
          <button 
            onClick={() => onNavigate('location')}
            className="p-6 bg-white rounded-3xl text-left ios-shadow card-hover group relative overflow-hidden"
          >
             <div className="absolute top-0 right-0 w-16 h-16 bg-blue-50 rounded-full blur-2xl translate-x-1/2 -translate-y-1/2" />
            <div className="w-12 h-12 bg-blue-50 rounded-2xl flex items-center justify-center mb-4 group-hover:bg-blue-600 transition-colors z-10 relative">
              <MapPin className="text-blue-600 w-6 h-6 group-hover:text-white transition-colors" />
            </div>
            <p className="font-bold text-slate-900 mb-1 z-10 relative">Live Tracking</p>
            <p className="text-[11px] text-slate-500 leading-tight font-medium opacity-80 z-10 relative">Share path and progress</p>
          </button>
        </div>

        {/* Informational Carousel */}
        <section className="bg-indigo-600 rounded-[2.5rem] p-8 text-white relative overflow-hidden">
          <div className="absolute top-0 right-0 w-32 h-32 bg-white/10 rounded-full blur-3xl -translate-y-1/2 translate-x-1/2" />
          <h4 className="text-[10px] font-black uppercase tracking-[0.3em] text-indigo-200 mb-4">Proactive Tip</h4>
          <p className="text-lg font-medium leading-relaxed mb-6 italic opacity-90">"Always stay in well-lit areas after sundown, and prefer the designated 'SafeNest' paths shared by your parents."</p>
          <div className="flex items-center gap-3">
             <div className="w-8 h-8 rounded-lg bg-indigo-500 flex items-center justify-center">
                <Shield className="w-4 h-4 text-indigo-100" />
             </div>
             <span className="text-xs font-bold uppercase tracking-widest text-indigo-100">AI Guardian Enabled</span>
          </div>
        </section>

        {/* History Preview */}
        <section className="pb-4">
          <div className="flex justify-between items-center mb-6">
            <h3 className="text-xl font-display font-bold text-slate-900">Recent Pulse</h3>
            <button onClick={() => onNavigate('history')} className="text-indigo-600 text-xs font-black uppercase tracking-widest">History</button>
          </div>
          <div className="space-y-4">
            {[
              { type: 'location', time: '12m ago', label: 'Home Arrived' },
              { type: 'sync', time: '1h ago', label: 'Parent Sync Complete' }
            ].map((activity, i) => (
              <div key={i} className="flex items-center p-4 bg-white rounded-[1.5rem] ios-shadow border border-slate-100/50">
                <div className="w-10 h-10 bg-slate-50 rounded-xl flex items-center justify-center mr-4">
                  {activity.type === 'location' ? <MapPin className="w-5 h-5 text-blue-500" /> : <History className="w-5 h-5 text-slate-400" />}
                </div>
                <div className="flex-1">
                  <p className="text-sm font-bold text-slate-800">{activity.label}</p>
                  <p className="text-[10px] text-slate-400 font-bold uppercase tracking-widest">{activity.time}</p>
                </div>
                <ChevronRight className="w-4 h-4 text-slate-300" />
              </div>
            ))}
          </div>
        </section>
      </main>
    </div>
  );
};

const ReportScreen = ({ profile, onBack }: { profile: UserProfile, onBack: () => void }) => {
  const [description, setDescription] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [safetyFeedback, setSafetyFeedback] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    try {
      const feedback = await processReportSafety(description);
      
      await addDoc(collection(db, 'reports'), {
        childUid: profile.uid,
        parentUid: profile.linkedUid || 'parent_demo_uid',
        description,
        safetyFeedback: feedback || '',
        status: 'pending',
        createdAt: serverTimestamp()
      });
      
      setSafetyFeedback(feedback || 'Report received.');
    } catch (e) {
      handleFirestoreError(e, 'create', '/reports', auth);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="flex flex-col h-full bg-white">
      <header className="px-8 pt-16 pb-6 flex items-center gap-4">
        <button onClick={onBack} className="w-10 h-10 bg-slate-50 rounded-xl flex items-center justify-center text-slate-400">
          <ArrowLeft className="w-5 h-5" />
        </button>
        <h2 className="text-2xl font-display font-bold text-slate-900 tracking-tight">Report</h2>
      </header>
      
      <form onSubmit={handleSubmit} className="flex-1 px-8 pt-4 space-y-8 overflow-y-auto pb-10">
        <div className="space-y-3">
          <label className="text-sm font-bold text-slate-500 uppercase tracking-widest">Description</label>
          <textarea 
            required
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="Tell us what's happening..."
            className="w-full h-48 p-6 bg-slate-50 rounded-[2rem] border-2 border-transparent focus:border-indigo-500 outline-none transition-all resize-none text-lg leading-relaxed placeholder:text-slate-300"
          />
        </div>

        <AnimatePresence>
          {safetyFeedback && (
            <motion.div 
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              className="p-6 bg-indigo-600 rounded-[2rem] text-white ios-shadow"
            >
              <div className="flex items-center gap-2 mb-3">
                <Shield className="w-5 h-5 text-indigo-200" />
                <span className="text-xs font-bold uppercase tracking-[0.2em] text-indigo-100">Safety Feedback</span>
              </div>
              <p className="text-lg font-medium leading-relaxed">{safetyFeedback}</p>
            </motion.div>
          )}
        </AnimatePresence>

        <Button disabled={isSubmitting} size="lg" className="w-full">
          {isSubmitting ? 'Sending...' : <><Send className="w-5 h-5" /> Submit Report</>}
        </Button>
      </form>
    </div>
  );
};

const StatusScreen = ({ profile, linkedProfile, onBack }: { profile: UserProfile, linkedProfile: UserProfile | null, onBack: () => void }) => {
  const [recentReports, setRecentReports] = useState<SafetyReport[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const q = query(
      collection(db, 'reports'),
      where(profile.role === 'child' ? 'childUid' : 'parentUid', '==', profile.uid),
      orderBy('createdAt', 'desc'),
      limit(10)
    );

    const unsubscribe = onSnapshot(q, (snapshot) => {
      const reports = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as SafetyReport));
      setRecentReports(reports);
      setLoading(false);
    });

    return () => unsubscribe();
  }, [profile]);

  return (
    <div className="flex flex-col h-full bg-slate-50">
      <header className="px-8 pt-16 pb-6 flex items-center gap-4">
        <button onClick={onBack} className="w-10 h-10 bg-white rounded-xl flex items-center justify-center text-slate-400 ios-shadow">
          <ArrowLeft className="w-5 h-5" />
        </button>
        <h2 className="text-2xl font-display font-bold text-slate-900 tracking-tight">Status</h2>
      </header>
      
      <div className="flex-1 px-8 pt-4 space-y-6 overflow-y-auto pb-10">
        {profile.role === 'parent' && linkedProfile && (
          <div className="p-8 bg-indigo-600 rounded-[2.5rem] text-white ios-shadow relative overflow-hidden">
            <div className="absolute top-0 right-0 w-32 h-32 bg-white/10 rounded-full blur-3xl -translate-y-1/2 translate-x-1/2" />
            <div className="flex items-center gap-4 mb-6">
              <div className="w-12 h-12 rounded-full border-2 border-white/50 p-0.5 overflow-hidden">
                <img src={`https://picsum.photos/seed/${linkedProfile.uid}/100/100`} className="w-full h-full rounded-full" alt="Child" />
              </div>
              <div>
                <p className="text-[10px] font-black uppercase tracking-[0.2em] text-indigo-200">Tracking Active</p>
                <h3 className="text-xl font-bold">{linkedProfile.displayName}</h3>
              </div>
            </div>
            
            <div className="space-y-4">
              <div className="flex items-center gap-3">
                <MapPin className="w-5 h-5 text-indigo-300" />
                <div>
                  <p className="text-[10px] font-bold text-indigo-300 uppercase leading-none mb-1">Coordinates</p>
                  <p className="text-sm font-medium">
                    {linkedProfile.lastKnownLocation 
                      ? `${linkedProfile.lastKnownLocation.lat.toFixed(4)}°, ${linkedProfile.lastKnownLocation.lng.toFixed(4)}°`
                      : 'Searching for GPS...'
                    }
                  </p>
                </div>
              </div>
              {linkedProfile.locationUpdatedAt && (
                <div className="flex items-center gap-3">
                  <History className="w-5 h-5 text-indigo-300" />
                  <div>
                    <p className="text-[10px] font-bold text-indigo-300 uppercase leading-none mb-1">Last Update</p>
                    <p className="text-sm font-medium">
                      {linkedProfile.locationUpdatedAt.toDate().toLocaleTimeString()}
                    </p>
                  </div>
                </div>
              )}
            </div>
          </div>
        )}

        <div className="p-8 bg-white rounded-[2.5rem] ios-shadow text-center">
          <div className="w-20 h-20 bg-emerald-50 rounded-full flex items-center justify-center mx-auto mb-6">
            <Shield className="text-emerald-600 w-10 h-10" />
          </div>
          <h3 className="text-2xl font-display font-bold text-slate-900 mb-2">
            {recentReports.some(r => r.id && recentReports[0]?.status === 'pending') ? 'Active Alerts' : 'All Systems Go'}
          </h3>
          <p className="text-slate-500">Monitoring your surroundings in real-time.</p>
        </div>
        
        <section>
          <h3 className="text-sm font-bold text-slate-400 uppercase tracking-widest mb-4 ml-2">History</h3>
          {loading ? (
            <div className="flex justify-center p-10"><Loader2 className="w-8 h-8 animate-spin text-indigo-600" /></div>
          ) : (
            <div className="space-y-3">
              {recentReports.map((report, i) => (
                <div key={report.id} className="flex items-center p-5 bg-white rounded-2xl ios-shadow">
                  <div className={`w-10 h-10 bg-indigo-50 rounded-xl flex items-center justify-center mr-4`}>
                    <Shield className={`w-5 h-5 text-indigo-600`} />
                  </div>
                  <div className="flex-1">
                    <p className="text-sm font-bold text-slate-800 line-clamp-1">{report.description}</p>
                    <p className="text-[10px] text-slate-400 font-bold uppercase tracking-wider">
                      {report.createdAt?.toDate().toLocaleString() || 'Recent'}
                    </p>
                  </div>
                  <div className={`w-2 h-2 rounded-full ${report.status === 'pending' ? 'bg-amber-400' : 'bg-slate-200'}`} />
                </div>
              ))}
              {recentReports.length === 0 && (
                <p className="text-center text-slate-400 py-10 italic">No historical reports found.</p>
              )}
            </div>
          )}
        </section>
      </div>
    </div>
  );
};

// --- Main App ---

export default function App() {
  const [user, setUser] = useState<FirebaseUser | null>(null);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [appState, setAppState] = useState<'landing' | 'onboarding' | 'linking' | 'main'>('landing');
  const [currentScreen, setCurrentScreen] = useState('home');
  const [showSourceInfo, setShowSourceInfo] = useState(false);
  const linkedProfile = useLocationSharing(profile);

  useEffect(() => {
    let profileUnsubscribe: (() => void) | null = null;
    
    const authUnsubscribe = onAuthStateChanged(auth, async (fbUser) => {
      setUser(fbUser);
      if (fbUser) {
        // Real-time profile listener
        profileUnsubscribe = onSnapshot(doc(db, 'users', fbUser.uid), (docSnap) => {
          if (docSnap.exists()) {
            const profileData = docSnap.data() as UserProfile;
            setProfile(profileData);
            
            // Auto-advance app state based on profile completeness
            setAppState(prev => {
              if (profileData.linkedUid && prev !== 'main') return 'main';
              if (prev === 'landing') return 'onboarding';
              return prev;
            });
          }
        });
      } else {
        setProfile(null);
        setAppState('landing');
        if (profileUnsubscribe) profileUnsubscribe();
      }
      setLoading(false);
    });

    return () => {
      authUnsubscribe();
      if (profileUnsubscribe) profileUnsubscribe();
    };
  }, []);

  const handleLogout = async () => {
    await auth.signOut();
    setAppState('landing');
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen bg-slate-100">
        <Loader2 className="w-12 h-12 animate-spin text-indigo-600" />
      </div>
    );
  }

  const renderAppContent = () => {
    if (appState === 'landing') {
      return <LandingPage onStart={() => setAppState('onboarding')} />;
    }

    if (!profile) {
      return (
        <AnimatePresence mode="wait">
          <motion.div
            key="login"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="h-full"
          >
            <LoginScreen onLogin={(p) => {
              setProfile(p);
              setAppState('onboarding');
            }} />
          </motion.div>
        </AnimatePresence>
      );
    }

    if (appState === 'onboarding') {
      return <OnboardingScreen role={profile.role} onComplete={() => setAppState('linking')} />;
    }
    if (appState === 'linking') {
      return <LinkingScreen user={profile} onLinked={() => setAppState('main')} />;
    }

    const renderScreen = () => {
      switch (currentScreen) {
        case 'home': return <HomeScreen profile={profile} linkedProfile={linkedProfile} onNavigate={setCurrentScreen} />;
        case 'report': return <ReportScreen profile={profile} onBack={() => setCurrentScreen('home')} />;
        case 'location': return <StatusScreen profile={profile} linkedProfile={linkedProfile} onBack={() => setCurrentScreen('home')} />;
        case 'history': return <StatusScreen profile={profile} linkedProfile={linkedProfile} onBack={() => setCurrentScreen('home')} />;
        default: return <HomeScreen profile={profile} linkedProfile={linkedProfile} onNavigate={setCurrentScreen} />;
      }
    };

    return (
      <div className="h-full flex flex-col">
        <div className="flex-1 overflow-hidden">
          <AnimatePresence mode="wait">
            <motion.div
              key={currentScreen}
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: -20 }}
              className="h-full"
            >
              {renderScreen()}
            </motion.div>
          </AnimatePresence>
        </div>
        
        {/* Bottom Nav */}
        <nav className="h-24 glass-nav flex items-center justify-around px-8 pb-6 shadow-2xl">
          <button 
            onClick={() => setCurrentScreen('home')}
            className={`p-3 rounded-2xl transition-all duration-300 ${currentScreen === 'home' ? 'text-indigo-600 bg-indigo-50 scale-110 shadow-lg shadow-indigo-100' : 'text-slate-300 hover:text-slate-500'}`}
          >
            <Shield className="w-7 h-7" />
          </button>
          <button 
            onClick={() => setCurrentScreen('location')}
            className={`p-3 rounded-2xl transition-all duration-300 ${currentScreen === 'location' ? 'text-indigo-600 bg-indigo-50 scale-110 shadow-lg shadow-indigo-100' : 'text-slate-300 hover:text-slate-500'}`}
          >
            <MapPin className="w-7 h-7" />
          </button>
          <button 
            onClick={() => setCurrentScreen('history')}
            className={`p-3 rounded-2xl transition-all duration-300 ${currentScreen === 'history' ? 'text-indigo-600 bg-indigo-50 scale-110 shadow-lg shadow-indigo-100' : 'text-slate-300 hover:text-slate-500'}`}
          >
            <History className="w-7 h-7" />
          </button>
          <button 
            onClick={handleLogout}
            className="p-3 rounded-2xl text-slate-300 hover:text-rose-600 transition-colors"
          >
            <LogOut className="w-7 h-7" />
          </button>
        </nav>
      </div>
    );
  };

  return (
    <div className="flex flex-col lg:flex-row min-h-screen bg-slate-100">
      {/* Sidebar Info (Desktop Only) */}
      <div className="hidden lg:flex flex-col w-[450px] p-12 bg-white border-r border-slate-200 overflow-y-auto selection:bg-indigo-50">
        <div className="mb-16">
          <div className="flex items-center gap-5 mb-8">
            <div className="w-14 h-14 bg-indigo-600 rounded-[1.25rem] flex items-center justify-center shadow-xl shadow-indigo-200">
              <Shield className="text-white w-8 h-8" />
            </div>
            <h1 className="text-4xl font-display font-black text-slate-900 tracking-tighter">SafeNest</h1>
          </div>
          <p className="text-slate-500 text-xl leading-relaxed font-medium">
            Building the world's most trusted sanctuary for families. No slop, just pure <span className="text-indigo-600 font-bold underline decoration-indigo-200 underline-offset-4">security</span>.
          </p>
        </div>

        <div className="space-y-10">
          <section className="p-8 bg-slate-900 rounded-[2.5rem] text-white ios-shadow-heavy relative overflow-hidden group">
            <div className="absolute top-0 right-0 w-32 h-32 bg-indigo-500/20 rounded-full blur-3xl -translate-y-1/2 translate-x-1/2 group-hover:bg-indigo-500/40 transition-colors" />
            <h3 className="text-[10px] font-black uppercase tracking-[0.3em] text-indigo-400 mb-4 flex items-center gap-2">
              <Lock className="w-4 h-4" /> Military Grade Encryption
            </h3>
            <p className="text-sm text-slate-300 leading-relaxed font-medium">
              Every data point, from GPS coordinates to safety reports, is siloed and encrypted using industry-standard protocols.
            </p>
          </section>

          <section>
            <h3 className="text-[10px] font-black text-slate-400 uppercase tracking-[0.3em] mb-6">System Architecture</h3>
            <div className="space-y-4">
              {[
                { title: "Real-time Sync", desc: "WebSocket-powered updates across all devices." },
                { title: "Role Isolation", desc: "Strict separation of Child and Parent access layers." },
                { title: "Behavioral Analytics", desc: "Non-invasive safety monitoring patterns." }
              ].map((item, i) => (
                <div key={i} className="p-6 bg-slate-50 rounded-[2rem] border border-slate-100 card-hover">
                  <p className="font-bold text-slate-900 mb-1">{item.title}</p>
                  <p className="text-xs text-slate-500 leading-relaxed font-medium">{item.desc}</p>
                </div>
              ))}
            </div>
          </section>
        </div>
      </div>

      {/* Simulator Area */}
      <div className="flex-1 flex items-center justify-center p-8">
        <div className="scale-[0.9] lg:scale-100">
          <MobileFrame>
            <AnimatePresence mode="wait">
              {renderAppContent()}
            </AnimatePresence>
          </MobileFrame>
        </div>
      </div>

      {/* Mobile Info Overlay (Mobile Only) */}
      <div className="lg:hidden fixed bottom-8 right-8 z-[100]">
        <button 
          onClick={() => setShowSourceInfo(!showSourceInfo)}
          className="w-16 h-16 bg-white text-indigo-600 rounded-3xl ios-shadow flex items-center justify-center active:scale-90 transition-transform border border-slate-100"
        >
          <Settings className="w-8 h-8" />
        </button>
      </div>
    </div>
  );
}
