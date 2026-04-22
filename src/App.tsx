import React from 'react';
import { Shield, Smartphone, Download, CheckCircle, Code2, Cpu } from 'lucide-react';

const LandingPage = () => {
  return (
    <div className="min-h-screen bg-slate-50 font-sans text-slate-900">
      {/* Header */}
      <header className="bg-white border-b border-slate-200 sticky top-0 z-10">
        <div className="max-w-5xl mx-auto px-6 h-16 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="bg-indigo-600 p-1.5 rounded-lg">
              <Shield className="w-5 h-5 text-white" />
            </div>
            <span className="font-bold text-xl tracking-tight">SafeNest <span className="text-indigo-600">Mobile</span></span>
          </div>
          <div className="flex items-center gap-4">
            <span className="text-xs font-medium bg-emerald-100 text-emerald-700 px-2 py-1 rounded-full uppercase tracking-wider">Project Active</span>
          </div>
        </div>
      </header>

      <main className="max-w-5xl mx-auto px-6 py-12">
        {/* Banner */}
        <section className="bg-indigo-600 rounded-3xl p-8 md:p-12 text-white relative overflow-hidden mb-12 shadow-2xl shadow-indigo-200">
          <div className="relative z-10 max-w-2xl">
            <h1 className="text-4xl md:text-5xl font-extrabold mb-6 leading-tight">
              AI-Based Child Safety<br/> Native Application
            </h1>
            <p className="text-indigo-100 text-lg mb-8 leading-relaxed">
              The SafeNest mobile codebase has been successfully migrated to <strong>Flutter</strong>. 
              The technical presentation is now centered on the native mobile implementation.
            </p>
            <div className="flex flex-wrap gap-4">
              <div className="bg-white/10 backdrop-blur-md rounded-xl p-4 border border-white/20 flex items-center gap-3">
                <Smartphone className="w-6 h-6" />
                <div>
                  <div className="text-xs uppercase opacity-70 font-bold">Platform</div>
                  <div className="font-bold underline cursor-pointer" onClick={() => window.alert('Check the /flutter_app folder in the file tree!')}>Flutter / Dart</div>
                </div>
              </div>
              <div className="bg-white/10 backdrop-blur-md rounded-xl p-4 border border-white/20 flex items-center gap-3">
                <Cpu className="w-6 h-6" />
                <div>
                  <div className="text-xs uppercase opacity-70 font-bold">AI Core</div>
                  <div className="font-bold">Gemini 1.5 Flash</div>
                </div>
              </div>
            </div>
          </div>
          {/* Decorative element */}
          <div className="absolute top-1/2 -right-20 -translate-y-1/2 w-80 h-80 bg-white/10 rounded-full blur-3xl"></div>
        </section>

        {/* Feature Grid */}
        <div className="grid md:grid-cols-2 gap-8 mb-16">
          <div className="bg-white p-8 rounded-3xl border border-slate-200 shadow-sm">
            <div className="w-12 h-12 bg-indigo-100 rounded-2xl flex items-center justify-center mb-6">
              <Code2 className="w-6 h-6 text-indigo-600" />
            </div>
            <h3 className="text-xl font-bold mb-4">Native Flutter App</h3>
            <p className="text-slate-600 mb-6 leading-relaxed">
              The full mobile implementation is located in the <code>/flutter_app</code> directory. It features real-time Firebase syncing, SOS handling, and AI analysis.
            </p>
            <div className="space-y-3">
              {['Dart 3.0+', 'Riverpod / Provider', 'Firebase Auth', 'Core Location'].map((tech) => (
                <div key={tech} className="flex items-center gap-2 text-sm font-medium text-slate-700">
                  <CheckCircle className="w-4 h-4 text-emerald-500" /> {tech}
                </div>
              ))}
            </div>
          </div>

          <div className="bg-indigo-50 p-8 rounded-3xl border border-indigo-100 shadow-sm">
            <div className="w-12 h-12 bg-indigo-600 rounded-2xl flex items-center justify-center mb-6 text-white">
              <Download className="w-6 h-6" />
            </div>
            <h3 className="text-xl font-bold mb-2">Web Archive</h3>
            <div className="text-xs font-bold text-indigo-600 uppercase mb-4 tracking-widest">Status: Frozen for Presentation</div>
            <p className="text-slate-600 mb-6 leading-relaxed">
              The previous React TypeScript version has been archived in <code>/react_web_archive</code>. It remains available for reference and logic comparison.
            </p>
             <button 
              className="w-full bg-white text-indigo-600 border border-indigo-200 font-bold py-3 px-6 rounded-xl hover:bg-indigo-100 transition-colors"
              onClick={() => window.alert('The React app is archived in the /react_web_archive folder.')}
            >
              Browse Archived Code
            </button>
          </div>
        </div>

        {/* Footer info */}
        <footer className="text-center text-slate-400 text-sm py-8 border-top border-slate-200">
          SafeNest Project Hub • Presentation Ready • 2026
        </footer>
      </main>
    </div>
  );
};

export default LandingPage;
