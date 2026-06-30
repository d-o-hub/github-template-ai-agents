/**
 * Avoid AI Writing — detection engine (canonical source of truth)
 * Implements 44-category pattern detection.
 */

const AIDetector = (() => {
  // ═══ Tier 1 pre-pass: normalize bypass tricks ══════════════════════
  const CYRILLIC_LOOKALIKES = {
    'а': 'a', 'е': 'e', 'о': 'o', 'р': 'p', 'с': 'c', 'х': 'x',
    'у': 'y', 'к': 'k', 'м': 'm', 'н': 'h', 'в': 'b', 'т': 't',
    'А': 'A', 'Е': 'E', 'О': 'O', 'Р': 'P', 'С': 'C', 'Х': 'X',
    'У': 'Y', 'К': 'K', 'М': 'M', 'Н': 'H', 'В': 'B', 'Т': 'T',
  };
  const GREEK_LOOKALIKES = { 'ο': 'o', 'Ο': 'O', 'α': 'a', 'Α': 'A', 'ρ': 'p', 'Ρ': 'P' };

  function normalizeText(text) {
    const flags = { zeroWidth: 0, homoglyph: 0, roleplay: 0 };
    let out = text;
    out = out.replace(/[​-‍﻿⁠]/g, () => { flags.zeroWidth++; return ''; });
    out = out.replace(/[Ѐ-ӿͰ-Ͽ]/g, (m) => {
      const swap = CYRILLIC_LOOKALIKES[m] ?? GREEK_LOOKALIKES[m];
      if (swap) { flags.homoglyph++; return swap; }
      return m;
    });
    const ROLEPLAY_VERBS = /^(?:nods|sighs|laughs|smiles|frowns|shrugs|grins|winks|chuckles|gasps|pauses|thinks|wonders|whispers|shouts|gestures|raises|leans|turns|looks|glances|smirks|blinks|nodding|sighing|laughing|smiling|thinking|gesturing)\b/i;
    out = out.replace(/(?<!\*)\*([^*\n]{1,80}?)\*(?!\*)/gu, (m, inner) => {
      if (ROLEPLAY_VERBS.test(inner)) { flags.roleplay++; return ''; }
      return m;
    });
    return { text: out, flags };
  }

  // ─── Tier 1: Always flag ───────────────────────────────────────────
  const TIER1 = {
    'delve': 'explore, dig into, look at',
    'tapestry': 'describe the actual complexity',
    'paradigm': 'model, approach, framework',
    'beacon': 'rewrite entirely',
    'robust': 'strong, reliable, solid',
    'comprehensive': 'thorough, complete, full',
    'cutting-edge': 'latest, newest, advanced',
    'pivotal': 'important, key, critical',
    'meticulous': 'careful, detailed, precise',
    'meticulously': 'carefully, precisely',
    'seamless': 'smooth, easy, without friction',
    'seamlessly': 'smoothly, easily',
    'game-changer': 'describe what changed',
    'game-changing': 'describe what changed',
    'nestled': 'is located, sits',
    'vibrant': 'describe what makes it active',
    'thriving': 'growing, active',
    'bustling': 'busy, active',
    'intricate': 'complex, detailed',
    'intricacies': 'complexities, details',
    'ever-evolving': 'changing, growing',
    'enduring': 'lasting, long-running',
    'daunting': 'hard, difficult',
    'holistic': 'complete, full, whole',
    'holistically': 'completely, fully',
    'actionable': 'practical, useful, concrete',
    'impactful': 'effective, significant',
    'learnings': 'lessons, findings, takeaways',
    'synergy': 'describe the combined effect',
    'synergies': 'describe the combined effect',
    'interplay': 'relationship, connection',
    'symphony': 'describe the coordination',
    'embrace': 'adopt, accept, use',
  };

  const TIER1_PHRASES = [
    { pattern: /\bdelve\s+into\b/gi, replace: 'explore, dig into' },
    { pattern: /\blandscape\b/gi, replace: 'field, space, industry' },
    { pattern: /\brealm\b/gi, replace: 'area, field, domain' },
    { pattern: /\btestament\s+to\b/gi, replace: 'shows, proves' },
    { pattern: /\bleverag(?:e|es|ing|ed)\b/gi, replace: 'use' },
    { pattern: /\bwatershed\s+moment\b/gi, replace: 'turning point, shift' },
    { pattern: /\bmarking\s+a\s+pivotal\s+moment\b/gi, replace: 'state what happened' },
    { pattern: /\bthe\s+future\s+looks\s+bright\b/gi, replace: 'cut or say something specific' },
    { pattern: /\bonly\s+time\s+will\s+tell\b/gi, replace: 'cut or say something specific' },
    { pattern: /\bdespite\s+challenges[^.]*continues?\s+to\s+thrive\b/gi, replace: 'name the challenge and response' },
    { pattern: /\bdeep\s+dive\b/gi, replace: 'look at, examine' },
    { pattern: /\bdive\s+into\b/gi, replace: 'look at, examine' },
    { pattern: /\bunpack(?:ing)?\b/gi, replace: 'explain, break down' },
    { pattern: /\bcomplexities\b/gi, replace: 'name the actual problems' },
    { pattern: /\bthought\s+leader(?:ship)?\b/gi, replace: 'expert, authority' },
    { pattern: /\bbest\s+practices\b/gi, replace: 'what works, proven methods' },
    { pattern: /\bat\s+its\s+core\b/gi, replace: 'cut, just state it' },
    { pattern: /\bin\s+order\s+to\b/gi, replace: 'to' },
    { pattern: /\bdue\s+to\s+the\s+fact\s+that\b/gi, replace: 'because' },
    { pattern: /\bserves\s+as\b/gi, replace: 'is' },
    { pattern: /\bfeatures\b/gi, replace: 'has, includes' },
    { pattern: /\bboasts\b/gi, replace: 'has' },
    { pattern: /\butiliz(?:e|es|ing|ed)\b/gi, replace: 'use' },
    { pattern: /\bshowcas(?:e|es|ing|ed)\b/gi, replace: 'show, demonstrate' },
    { pattern: /\bembark(?:s|ing|ed)?\b/gi, replace: 'start, begin' },
    { pattern: /\bcommenc(?:e|es|ing|ed)\b/gi, replace: 'start, begin' },
    { pattern: /\bascertain(?:s|ing|ed)?\b/gi, replace: 'find out, determine' },
    { pattern: /\bendeavou?r(?:s|ing|ed)?\b/gi, replace: 'effort, attempt, try' },
    { pattern: /\bunderscor(?:es|ing|ed)\b/gi, replace: 'highlights, shows' },
  ];

  // ─── Tier 2: Flag in clusters (2+ per paragraph) ──────────────────
  const TIER2 = {
    'harness': 'use, take advantage of',
    'navigate': 'work through, handle',
    'navigating': 'working through, handling',
    'foster': 'encourage, support, build',
    'elevate': 'improve, raise, strengthen',
    'unleash': 'release, enable, unlock',
    'streamline': 'simplify, speed up',
    'empower': 'enable, let, allow',
    'bolster': 'support, strengthen',
    'spearhead': 'lead, drive, run',
    'resonate': 'connect with, appeal to',
    'resonates': 'connects with, appeals to',
    'revolutionize': 'change, transform',
    'facilitate': 'enable, help, allow',
    'facilitates': 'enables, helps, allows',
    'underpin': 'support, form the basis of',
    'nuanced': 'specific, subtle, detailed',
    'crucial': 'important, key, necessary',
    'multifaceted': 'describe the actual facets',
    'ecosystem': 'system, community, network',
    'myriad': 'many, numerous',
    'plethora': 'many, a lot of',
    'encompass': 'include, cover, span',
    'catalyze': 'start, trigger, accelerate',
    'reimagine': 'rethink, redesign, rebuild',
    'galvanize': 'motivate, rally, push',
    'augment': 'add to, expand, supplement',
    'cultivate': 'build, develop, grow',
    'illuminate': 'clarify, explain, show',
    'elucidate': 'explain, clarify',
    'juxtapose': 'compare, contrast',
    'transformative': 'describe what changed',
    'transformation': 'describe what changed',
    'cornerstone': 'foundation, basis, key part',
    'paramount': 'most important, top priority',
    'poised': 'ready, set, about to',
    'burgeoning': 'growing, emerging',
    'nascent': 'new, early-stage',
    'quintessential': 'typical, classic, defining',
    'overarching': 'main, central, broad',
    'underpinning': 'basis, foundation',
    'underpinnings': 'basis, foundations',
    'paradigm-shifting': 'describe what shifted',
  };

  // ─── Tier 3: Flag by density ───────────────────────────────────────
  const TIER3 = [
    'significant', 'significantly', 'innovative', 'innovation',
    'effective', 'effectively', 'dynamic', 'dynamics',
    'scalable', 'scalability', 'compelling', 'unprecedented',
    'exceptional', 'exceptionally', 'remarkable', 'remarkably',
    'sophisticated', 'instrumental',
    'world-class', 'state-of-the-art', 'best-in-class',
  ];

  const TIER3_PHRASES = [
    /\bemerging\s+(?:sector|space|category|industry)\b/gi,
    /\bthe\s+integration\s+of\b/gi,
    /\bthe\s+intersection\s+of\b/gi,
    /\bcommunity-?driven\b/gi,
    /\blong-?term\s+sustainability\b/gi,
    /\buser\s+engagement\b/gi,
    /\bdecentralized\s+compute\b/gi,
    /\b(?:sustainable\s+)?reward\s+emissions?\b/gi,
    /\btokenized\s+incentive\s+structures?\b/gi,
    /\bdesigned\s+for\s+long-?term\b/gi,
  ];

  const TIER3_LOOKUP = new Map();
  for (const word of TIER3) {
    TIER3_LOOKUP.set(word, word);
    const dashless = word.replace(/-/g, '');
    if (dashless !== word) TIER3_LOOKUP.set(dashless, word);
  }

  const ISSUE_WEIGHTS = {
    tier1: 5, tier2: 3, tier3: 2, transition: 2, chatbot: 8, sycophantic: 8, filler: 2,
    'generic-conclusion': 3, 'lets-construction': 2, 'reasoning-artifact': 6,
    'acknowledgment-loop': 3, 'significance-inflation': 4, 'vague-attribution': 5,
    'hollow-intensifier': 2, 'emotional-flatline': 2, 'novelty-inflation': 3,
    'cutoff-disclaimer': 10, 'template-phrase': 3, 'false-concession': 2,
    'rhetorical-question': 2, 'confidence-calibration': 2, 'em-dash': 4,
    uniformity: 5, formatting: 3, 'tier3-phrase': 3, 'tier3-phrase-cluster': 12,
    'hashtag-stuff': 12, 'bullet-np-list': 10, 'hedge-stack': 6, 'future-narrative': 12,
    'real-actual-inflation': 5, 'social-cta-closer': 8, 'formulaic-opener': 8,
    'title-case-header': 4, 'parenthetical-hedge': 3, 'smart-punct-signature': 6,
    'punct-distribution': 6, 'fnword-trigram-entropy': 5, 'cross-para-burstiness': 5,
    'normalization-flag': 9, 'low-ttr': 3, 'ai-placeholder': 10,
    'ai-citation-markup': 15, 'ai-utm-source': 12,
  };

  const TRANSITIONS = [
    /\bmoreover\b/gi, /\bfurthermore\b/gi, /\badditionally\b/gi, /\bin\s+today'?s\b/gi,
    /\bin\s+an\s+era\s+where\b/gi, /\bit'?s\s+worth\s+noting\s+that\b/gi, /\bnotably\b/gi,
    /\bin\s+conclusion\b/gi, /\bin\s+summary\b/gi, /\bto\s+summarize\b/gi,
    /\bwhen\s+it\s+comes\s+to\b/gi, /\bat\s+the\s+end\s+of\s+the\s+day\b/gi, /\bthat\s+(?:being\s+)?said\b/gi,
  ];

  const CHATBOT_ARTIFACTS = [
    /\bi\s+hope\s+this\s+helps\b/gi, /\bcertainly!\b/gi, /\babsolutely!\b/gi,
    /\bgreat\s+question!\b/gi, /\bexcellent\s+point!\b/gi, /\bfeel\s+free\s+to\s+reach\s+out\b/gi,
    /\blet\s+me\s+know\s+if\s+you\s+need\s+anything\b/gi, /\bin\s+this\s+article,?\s+we\s+will\s+explore\b/gi,
    /\blet'?s\s+dive\s+in!?\b/gi,
  ];

  const SYCOPHANTIC = [
    /\byou'?re\s+absolutely\s+right\b/gi, /\bthat'?s\s+a\s+really\s+insightful\b/gi,
    /\bthat'?s\s+a\s+great\s+question\b/gi, /\bexcellent\s+question\b/gi,
  ];

  const FILLERS = [
    /\bit\s+is\s+important\s+to\s+note\s+that\b/gi, /\bin\s+terms\s+of\b/gi,
    /\bthe\s+reality\s+is\s+that\b/gi, /\bit'?s\s+important\s+to\s+note\s+that\b/gi,
  ];

  const GENERIC_CONCLUSIONS = [
    /\bthe\s+future\s+looks\s+bright\b/gi, /\bonly\s+time\s+will\s+tell\b/gi,
    /\bone\s+thing\s+is\s+certain\b/gi, /\bas\s+we\s+move\s+forward\b/gi,
  ];

  const LETS_PATTERNS = [
    /\blet'?s\s+explore\b/gi, /\blet'?s\s+take\s+a\s+look\b/gi, /\blet'?s\s+break\s+this\s+down\b/gi,
    /\blet'?s\s+examine\b/gi, /\blet'?s\s+(?:consider|discuss|delve|unpack|walk\s+through)\b/gi,
  ];

  const REASONING_ARTIFACTS = [
    /\blet\s+me\s+think\s+step\s+by\s+step\b/gi, /\bbreaking\s+this\s+down\b/gi,
    /\bto\s+approach\s+this\s+systematically\b/gi, /\bhere'?s\s+my\s+thought\s+process\b/gi,
    /\bfirst,?\s+let'?s\s+consider\b/gi, /\bworking\s+through\s+this\s+logically\b/gi,
  ];

  const ACKNOWLEDGMENT_LOOPS = [
    /\byou'?re\s+asking\s+about\b/gi, /\bthe\s+question\s+of\s+whether\b/gi, /\bto\s+answer\s+your\s+question\b/gi,
  ];

  const SIGNIFICANCE_INFLATION = [
    /\bmarking\s+a\s+(?:pivotal|significant|important)\s+moment\b/gi, /\ba\s+watershed\s+moment\s+for\b/gi,
    /\bin\s+the\s+evolution\s+of\b/gi, /\ba\s+(?:pivotal|defining)\s+moment\s+in\b/gi,
  ];

  const VAGUE_ATTRIBUTIONS = [
    /\bexperts\s+(?:believe|say|suggest|agree)\b/gi, /\bstudies\s+(?:show|suggest|indicate)\b/gi,
    /\bresearch\s+(?:shows|suggests|indicates)\b/gi, /\bindustry\s+leaders\s+(?:agree|believe|say)\b/gi,
  ];

  const HOLLOW_INTENSIFIERS = [
    /\bgenuine(?:ly)?\b/gi, /\btruly\b/gi, /\bquite\s+frankly\b/gi, /\bto\s+be\s+honest\b/gi,
    /\blet'?s\s+be\s+clear\b/gi,
  ];

  const EMOTIONAL_FLATLINE = [
    /\bwhat\s+surprised\s+me\s+most\b/gi, /\bi\s+was\s+fascinated\s+to\b/gi, /\bwhat\s+struck\s+me\s+was\b/gi,
    /\bi\s+was\s+excited\s+to\s+learn\b/gi, /\bthe\s+most\s+interesting\s+(?:part|thing|aspect|piece)\b/gi,
    /^\s*interesting\s+(?:part|thing|aspect|piece)(?:\s+of\s+(?:the\s+)?\w+)?\s*:/gim,
  ];

  const NOVELTY_INFLATION = [
    /\bthe\s+failure\s+mode\s+nobody'?s?\s+naming\b/gi, /\ba\s+problem\s+nobody\s+talks\s+about\b/gi,
    /\bthe\s+insight\s+everyone'?s?\s+missing\b/gi, /\bwhat\s+nobody\s+tells\s+you\b/gi,
  ];

  const CUTOFF_DISCLAIMERS = [
    /\bas\s+of\s+my\s+last\s+update\b/gi, /\bas\s+of\s+my\s+(?:knowledge\s+)?(?:cut-?off|last\s+training)\b/gi,
    /\bi\s+don'?t\s+have\s+access\s+to\s+real-?time\s+(?:data|information)\b/gi, /\bbased\s+on\s+available\s+information\b/gi,
    /\bas\s+an?\s+(?:ai|artificial\s+intelligence|large\s+language|ai\s+language)\s+(?:language\s+)?model\b/gi,
    /\bi\s+(?:am|'m)\s+an?\s+(?:ai|artificial\s+intelligence|large\s+language)\s+(?:assistant|model)?\b/gi,
    /\bi\s+cannot\s+(?:provide|give|offer)\s+(?:legal|medical|financial|professional)\s+advice\b/gi,
    /\bmy\s+training\s+data\s+(?:only\s+)?(?:goes\s+up\s+to|extends\s+to|ends\s+(?:in|at))\b/gi,
  ];

  const AI_PLACEHOLDERS = [
    /\[(?:Your|Insert|Add|Enter|Describe|Specify|Choose|Pick)[^\]\n]{1,80}\]/gi,
    /\[(?:Recipient|Sender|Topic|Subject|Salutation|Closing|Position|Department|Project Name|Company Name|Date)(?:\s+[^\]\n]{0,60})?\]/gi,
    /\[(?:INSERT|FILL\s+IN|ADD|TODO|TBD|PLACEHOLDER)[^\]\n]{0,80}\]/g,
    /\b(?:19|20)\d{2}-XX-XX\b/g, /\bXX\/XX\/(?:19|20)\d{2}\b/g,
    /<!--\s*(?:add|fill\s+in|insert|todo|placeholder)[^>]{0,120}-->/gi,
  ];

  const AI_CITATION_MARKUP = [
    /\bcite(?:turn|news|search|navigation)\d+(?:search|turn|news|navigation)\d+/gi,
    /contentReference\s*\[oaicite:[^\]]+\]\s*\{[^}]*\}/gi,
    /\boai_citation\b/gi, /\[attached_file:\d+\]/gi, /\bgrok_card\b/gi,
  ];

  const AI_UTM_SOURCE = [
    /[?&]utm_source=(?:chatgpt|openai|copilot|claude|grok|gemini|perplexity)(?:\.com|\.ai)?\b/gi,
    /[?&]referrer=(?:chatgpt|copilot|grok|claude|gemini|perplexity)\.(?:com|ai)\b/gi,
  ];

  const TEMPLATE_PHRASES = [
    /\ba\s+\w+\s+step\s+(?:towards?|forward\s+for)\b/gi, /\bwhether\s+you'?re\s+\w+\s+or\s+\w+/gi,
    /\bi\s+recently\s+had\s+the\s+pleasure\s+of\b/gi,
  ];

  const FALSE_CONCESSION = [
    /\bwhile\s+\w+\s+is\s+impressive\b/gi, /\balthough\s+\w+\s+has\s+made\s+strides\b/gi,
    /\bdespite\s+\w+\s+challenges?\b/gi,
  ];

  const RHETORICAL_QUESTIONS = [
    /\bbut\s+what\s+does\s+this\s+mean\s+for\b/gi, /\bso\s+why\s+should\s+you\s+care\b/gi,
    /\bwhat'?s\s+next\?\s*/gi,
  ];

  const HEDGE_STACK = [
    /\b(?:could|may|might)\s+(?:\w+\s+){0,2}(?:potentially|eventually|ultimately|possibly|conceivably)\b/gi,
    /\b(?:potentially|eventually|ultimately)\s+(?:could|may|might)\b/gi,
  ];

  const FUTURE_NARRATIVE = [
    /\b(?:may|could|will|is\s+(?:poised|set)\s+to)\s+become\s+(?:one\s+of\s+)?(?:the\s+)?(?:most\s+)?\w+\s+(?:narratives?|stories|developments?|trends?|movements?|chapters?|themes?|forces?)\b/gi,
    /\bone\s+of\s+the\s+most\s+important\s+(?:narratives?|stories|trends?|themes?)\s+of\s+the\s+(?:next|coming)\s+\w+\b/gi,
  ];

  const REAL_ACTUAL_INFLATION = [
    /\b(?:real|actual|genuine|true)\s+(?:on-?chain\s+)?(?:tokenomics|economics|utility|adoption|sustainability|impact|revenue|fundamentals|demand|value|innovation|traction)\b/gi,
  ];

  const FORMULAIC_OPENERS = [
    /\bin\s+the\s+(?:rapidly\s+|ever-?\s*)?(?:evolving|changing|expanding|growing|shifting)\s+(?:world|landscape|realm|space|field|domain|era)\s+of\b/gi,
    /\bin\s+(?:an?|the)\s+(?:digital\s+)?age\s+(?:where|of)\b/gi,
    /\bas\s+(?:we|the\s+world|society|industries?)\s+(?:continue|move|navigate|enter)\s+(?:to\s+)?(?:evolve|forward|into|through)\b/gi,
    /\bhas\s+emerged\s+as\s+(?:a|the|one\s+of)\s+(?:leading|key|major|critical|essential|fundamental|pivotal|prominent|dominant|important)\s+\w+/gi,
    /\bhas\s+become\s+increasingly\s+(?:important|critical|popular|relevant|prominent|essential)\b/gi,
  ];

  const TITLE_CASE_HEADER = /^([A-Z][a-z]+(?:\s+(?:[A-Z][a-z]+|and|or|of|the|in|for|to|a|an))+\s+[A-Z][a-z]+)\s*$/gm;

  const PARENTHETICAL_HEDGE = [
    /\(\s*(?:and\s+)?(?:increasingly|notably|importantly|crucially|interestingly|perhaps)[,]?\s+[^)]{3,60}\)/gi,
    /\(\s*or\s+more\s+(?:precisely|accurately|specifically)[,]?\s+[^)]{3,60}\)/gi,
    /\(\s*though\s+to\s+be\s+fair[,]?\s+[^)]{3,60}\)/gi,
    /\(\s*at\s+least\s+(?:in\s+)?(?:theory|principle|part)[,]?\s+[^)]{0,60}\)/gi,
  ];

  const CONFIDENCE_CALIBRATION = [
    /\binterestingly\b/gi, /\bsurprisingly\b/gi, /\bimportantly\b/gi, /\bsignificantly\b/gi,
    /\bcertainly\b/gi, /\bundoubtedly\b/gi, /\bwithout\s+a\s+doubt\b/gi,
  ];

  const SOCIAL_CTA_CLOSER = [
    /\bthis\s+one['’]?s?\s+(?:is\s+)?(?:well\s+|totally\s+|absolutely\s+|definitely\s+|really\s+|truly\s+|easily\s+|more\s+than\s+)?worth\s+(?:your\s+time|the\s+read|a\s+read|every\s+(?:minute|second)|reading|watching|a\s+listen|a\s+watch|a\s+look|it)\b/gi,
    /\bthis\s+one['’]?s?\s+(?:is\s+)?a\s+must[-\s]?(?:read|watch|listen|see)\b/gi,
    /\b(?:highly|strongly|can['’]?t|cannot)\s+recommend\w*\s+(?:giving\s+)?(?:this|it)\s+(?:one\s+)?a\s+(?:read|listen|watch|look|go)\b/gi,
    /\bdo\s+yourself\s+a\s+favou?r\s+and\s+(?:read|watch|check\s+out)\s+(?:this|it)\b/gi,
    /\byou\s+(?:really\s+)?(?:won['’]?t|do\s*n['’]?t|will\s+not|do\s+not)\s+want\s+to\s+miss\s+this(?:\s+one)?(?=\s*(?:[:.!\n]|$))/gi,
    /(?<=^|[,.!?:\n]\s{0,4})(?:you\s+can\s+)?thank\s+me\s+later\b/gim,
    /(?<=^|[.!?:\n]\s{0,4})save\s+this\s+(?:one\s+)?for\s+later\b/gim,
    /\bbookmark\s+this(?:\s+(?:one|post|thread))?(?=\s*(?:[:.!\n]|$))/gi,
    /\bdo\s*n['’]?t\s+sleep\s+on\s+this\b/gi,
    /\btrust\s+me,?\s+(?:on\s+this|you['’]?ll)\b/gi,
  ];

  // ═══ Helpers ═══════════════════════════════════════════════════════

  function tokenize(text) { return text.toLowerCase().match(/[\w'-]+/g) || []; }
  function countWords(text) { return (text.match(/\S+/g) || []).length; }
  function getParagraphs(text) { return text.split(/\n\s*\n/).filter(p => p.trim().length > 0); }
  function getSentences(text) { return text.split(/[.!?]+/).filter(s => s.trim().length > 5); }

  function matchPatterns(text, patterns, category, severity) {
    const issues = [];
    for (const pat of patterns) {
      const regex = new RegExp(pat.source, pat.flags);
      let match;
      while ((match = regex.exec(text)) !== null) {
        issues.push({ type: category, text: match[0], index: match.index, severity, suggestion: null });
      }
    }
    return issues;
  }

  function deduplicateIssues(issues) {
    const seen = new Set();
    return issues.filter(issue => {
      const key = `${issue.type}:${issue.text.toLowerCase()}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
  }

  // ═══ Main analysis ═════════════════════════════════════════════════

  function analyzeText(text, options = {}) {
    if (!text || text.trim().length === 0) return { score: 0, label: 'Empty', issues: [], stats: {}, tooShort: true };
    const norm = normalizeText(text);
    text = norm.text;
    const wordCount = countWords(text);
    if (wordCount < 10) return { score: 0, label: 'Too short', issues: [], stats: { wordCount }, tooShort: true };

    const tokens = tokenize(text);
    const paragraphs = getParagraphs(text);
    const issues = [];
    let rawScore = 0;

    // 1. Tier 1
    const tier1Found = new Set();
    for (const token of tokens) {
      if (TIER1[token] && !tier1Found.has(token)) {
        tier1Found.add(token);
        issues.push({ type: 'tier1', text: token, severity: 'high', suggestion: TIER1[token] });
      }
    }
    for (const phrase of TIER1_PHRASES) {
      const regex = new RegExp(phrase.pattern.source, phrase.pattern.flags);
      let match;
      while ((match = regex.exec(text)) !== null) {
        const lower = match[0].toLowerCase();
        if (tier1Found.has(lower)) continue;
        tier1Found.add(lower);
        issues.push({ type: 'tier1', text: match[0], severity: 'high', suggestion: phrase.replace });
      }
    }

    // 2. Tier 2
    let tier2Clusters = 0;
    for (const para of paragraphs) {
      const found = [];
      const paraTokens = tokenize(para);
      for (const token of paraTokens) { if (TIER2[token] && !found.includes(token)) found.push(token); }
      if (found.length >= 2) {
        tier2Clusters++;
        found.forEach(word => issues.push({ type: 'tier2', text: word, severity: 'medium', suggestion: TIER2[word] }));
      }
    }

    // 3. Tier 3
    const tier3Counts = {};
    tokens.forEach(token => {
      const canonical = TIER3_LOOKUP.get(token);
      if (canonical) tier3Counts[canonical] = (tier3Counts[canonical] || 0) + 1;
    });
    const densityThreshold = Math.max(3, Math.floor(wordCount * 0.03));
    for (const [word, count] of Object.entries(tier3Counts)) {
      if (count >= densityThreshold) issues.push({ type: 'tier3', text: `"${word}" x${count}`, severity: 'low', suggestion: `Overused (${count} times)` });
    }

    // Tier 3 Phrases
    let distinctPhrasesHit = 0;
    for (const phrase of TIER3_PHRASES) {
      const regex = new RegExp(phrase.source, phrase.flags);
      const matches = text.match(regex);
      if (matches) {
        distinctPhrasesHit++;
        if (matches.length >= 2) {
          issues.push({ type: 'tier3-phrase', text: `"${matches[0].toLowerCase()}" x${matches.length}`, severity: 'medium', suggestion: `Boilerplate phrase repeated` });
        }
      }
    }
    if (distinctPhrasesHit >= 3) {
      issues.push({ type: 'tier3-phrase-cluster', text: `${distinctPhrasesHit} distinct boilerplate phrases`, severity: 'high', suggestion: 'Rewrite around specifics' });
    }

    // 4+. Other patterns
    issues.push(...matchPatterns(text, TRANSITIONS, 'transition', 'medium'));
    issues.push(...matchPatterns(text, CHATBOT_ARTIFACTS, 'chatbot', 'critical'));
    issues.push(...matchPatterns(text, SYCOPHANTIC, 'sycophantic', 'critical'));
    issues.push(...matchPatterns(text, FILLERS, 'filler', 'medium'));
    issues.push(...matchPatterns(text, GENERIC_CONCLUSIONS, 'generic-conclusion', 'medium'));
    issues.push(...matchPatterns(text, LETS_PATTERNS, 'lets-construction', 'medium'));
    issues.push(...matchPatterns(text, REASONING_ARTIFACTS, 'reasoning-artifact', 'critical'));
    issues.push(...matchPatterns(text, ACKNOWLEDGMENT_LOOPS, 'acknowledgment-loop', 'medium'));
    issues.push(...matchPatterns(text, SIGNIFICANCE_INFLATION, 'significance-inflation', 'high'));
    issues.push(...matchPatterns(text, VAGUE_ATTRIBUTIONS, 'vague-attribution', 'critical'));
    issues.push(...matchPatterns(text, HOLLOW_INTENSIFIERS, 'hollow-intensifier', 'medium'));
    issues.push(...matchPatterns(text, EMOTIONAL_FLATLINE, 'emotional-flatline', 'low'));
    issues.push(...matchPatterns(text, NOVELTY_INFLATION, 'novelty-inflation', 'medium'));
    issues.push(...matchPatterns(text, CUTOFF_DISCLAIMERS, 'cutoff-disclaimer', 'critical'));
    issues.push(...matchPatterns(text, AI_PLACEHOLDERS, 'ai-placeholder', 'critical'));
    issues.push(...matchPatterns(text, AI_CITATION_MARKUP, 'ai-citation-markup', 'critical'));
    issues.push(...matchPatterns(text, AI_UTM_SOURCE, 'ai-utm-source', 'critical'));
    issues.push(...matchPatterns(text, TEMPLATE_PHRASES, 'template-phrase', 'high'));
    issues.push(...matchPatterns(text, FALSE_CONCESSION, 'false-concession', 'medium'));
    issues.push(...matchPatterns(text, RHETORICAL_QUESTIONS, 'rhetorical-question', 'medium'));
    issues.push(...matchPatterns(text, HEDGE_STACK, 'hedge-stack', 'high'));
    issues.push(...matchPatterns(text, FUTURE_NARRATIVE, 'future-narrative', 'high'));
    issues.push(...matchPatterns(text, REAL_ACTUAL_INFLATION, 'real-actual-inflation', 'medium'));
    issues.push(...matchPatterns(text, SOCIAL_CTA_CLOSER, 'social-cta-closer', 'high'));
    issues.push(...matchPatterns(text, FORMULAIC_OPENERS, 'formulaic-opener', 'high'));
    issues.push(...matchPatterns(text, PARENTHETICAL_HEDGE, 'parenthetical-hedge', 'medium'));

    const deduped = deduplicateIssues(issues);
    for (const issue of deduped) { rawScore += ISSUE_WEIGHTS[issue.type] || 2; }
    const lengthFactor = Math.max(1, Math.log2(wordCount / 50));
    const normalizedScore = Math.min(100, Math.round(rawScore / lengthFactor));

    return { score: normalizedScore, label: getLabel(normalizedScore), issues: deduped, stats: { wordCount, tier2Clusters } };
  }

  function getLabel(score) {
    if (score === 0) return 'Clean';
    if (score <= 15) return 'Minimal AI signals';
    if (score <= 35) return 'Some AI patterns';
    if (score <= 60) return 'Moderate AI signals';
    if (score <= 80) return 'Strong AI signals';
    return 'Heavy AI patterns';
  }

  const SEVERITY_LABELS = { critical: 'P0', high: 'P1', medium: 'P2', low: 'P3' };
  const TYPE_LABELS = {
    'tier1': 'AI vocabulary', 'tier2': 'Word cluster', 'tier3': 'Overused word',
    'transition': 'AI transition', 'chatbot': 'Chatbot artifact', 'sycophantic': 'Sycophantic tone',
    'filler': 'Filler phrase', 'generic-conclusion': 'Generic conclusion', 'lets-construction': '"Let\'s" opener',
    'reasoning-artifact': 'Reasoning artifact', 'acknowledgment-loop': 'Acknowledgment loop',
    'significance-inflation': 'Significance inflation', 'vague-attribution': 'Vague attribution',
    'hollow-intensifier': 'Hollow intensifier', 'emotional-flatline': 'Emotional flatline',
    'novelty-inflation': 'Novelty inflation', 'cutoff-disclaimer': 'Cutoff disclaimer',
    'template-phrase': 'Template phrase', 'false-concession': 'False concession',
    'rhetorical-question': 'Rhetorical question', 'confidence-calibration': 'Confidence stacking',
    'em-dash': 'Em dash overuse', 'uniformity': 'Rhythm uniformity', 'formatting': 'Formatting',
    'tier3-phrase': 'Boilerplate phrase', 'tier3-phrase-cluster': 'Boilerplate cluster',
    'hashtag-stuff': 'Hashtag stuffing', 'bullet-np-list': 'Bullet-NP list',
    'hedge-stack': 'Hedge-stacked prediction', 'future-narrative': 'Generic future narrative',
    'real-actual-inflation': '"Real/actual" inflation', 'social-cta-closer': 'Engagement-bait closer',
    'formulaic-opener': 'Formulaic opener', 'title-case-header': 'Title Case header',
    'parenthetical-hedge': 'Parenthetical hedge', 'smart-punct-signature': 'Smart-punct signature',
    'punct-distribution': 'Punctuation distribution', 'fnword-trigram-entropy': 'Grammar repetition',
    'cross-para-burstiness': 'Cross-paragraph rhythm', 'normalization-flag': 'Bypass-trick chars',
    'low-ttr': 'Low vocabulary diversity', 'ai-placeholder': 'Unfilled placeholder',
    'ai-citation-markup': 'Chatbot citation markup leak', 'ai-utm-source': 'AI-tool URL parameter',
  };

  return { analyzeText, normalizeText, getLabel, TIER1, TIER1_PHRASES, TIER2, SEVERITY_LABELS, TYPE_LABELS };
})();

if (typeof module !== 'undefined' && module.exports) { module.exports = AIDetector; }
