# Dipole Cold Start Bundle

Use this when starting a new ChatGPT session after time away.

Paste the following messages in order:

---

### **Message 1 — High-Level Project Summary**
Paste sections 1–3 from PROJECT_STATE.md.

---

### **Message 2 — Current Experiment**
Paste the dev-log summary for the current experiment.

---

### **Message 3 — Relevant Code**
Paste:
- LLDBDriver
- Any experiment code being worked on
- Any failing test or output

---

### **Message 4 — Active Questions**
Tell ChatGPT exactly what you want to work on today.

---

### **Message 5 — Constraints / Priorities**
(Examples)
- preserve clean API boundaries
- no Codex-style brute-force hacks
- prefer architectural clarity over raw speed
- keep Apple Silicon quirks in mind
