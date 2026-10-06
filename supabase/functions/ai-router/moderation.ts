export class ModerationService {
  private prohibitedPatterns = [
    /\b(hack|exploit|malware|ransomware|ddos)\b/i,
    /\b(nazi|terrorist|isis|hitler)\b/i,
    /\b(cp|csam|child\s*abuse)\b/i,
    /\b(suicide|self-harm)\b/i,
  ];

  async checkInput(input: any): Promise<{ allowed: boolean; reason?: string }> {
    const textToCheck = typeof input === "string" ? input : JSON.stringify(input);

    for (const pattern of this.prohibitedPatterns) {
      if (pattern.test(textToCheck)) {
        return {
          allowed: false,
          reason: "Tu solicitud contiene términos no permitidos por nuestras políticas de seguridad.",
        };
      }
    }

    return { allowed: true };
  }
}
