import { GoogleGenAI } from "@google/genai";

// Initialize for safety processing
const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });

export async function processReportSafety(description: string) {
  try {
    const response = await ai.models.generateContent({
      model: "gemini-3-flash-preview",
      contents: `Analyze this safety report: "${description}". Provide a brief risk level assessment (Low, Medium, High) and any immediate advice.`,
    });
    return response.text;
  } catch (error) {
    console.error("Safety processing error:", error);
    return "Report received and being processed.";
  }
}
