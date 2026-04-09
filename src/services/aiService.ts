import { GoogleGenAI } from "@google/genai";

// Initialize Gemini for advanced safety analysis
// In AI Studio, process.env.GEMINI_API_KEY is automatically injected
const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });

export async function analyzeSafety(description: string) {
  try {
    const response = await ai.models.generateContent({
      model: "gemini-3-flash-preview",
      contents: `Analyze this safety report from a child: "${description}". Is it an emergency? Provide a brief risk level (Low, Medium, High).`,
    });
    return response.text;
  } catch (error) {
    console.error("Gemini analysis error:", error);
    return "Error analyzing report.";
  }
}
