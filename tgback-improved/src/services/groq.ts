import Groq from 'groq-sdk';

const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

export async function getAIResponse(
  userMessage: string,
  chatHistory: { role: 'user' | 'assistant'; content: string }[] = []
): Promise<string> {
  const messages = [
    {
      role: 'system' as const,
      content: `Ты умный AI-ассистент в мессенджере. Помогаешь пользователям с вопросами, переводишь текст, анализируешь переписку, предлагаешь ответы. Отвечай кратко, ясно и по делу. Используй Markdown для форматирования если нужно. Текущая дата: ${new Date().toLocaleDateString('ru-RU')}.`,
    },
    ...chatHistory.slice(-15),
    { role: 'user' as const, content: userMessage },
  ];

  const completion = await groq.chat.completions.create({
    model: 'llama-3.3-70b-versatile',
    messages,
    max_tokens: 1024,
    temperature: 0.7,
  });

  return completion.choices[0]?.message?.content || 'Не могу ответить на этот запрос.';
}

export async function summarizeChat(
  messages: { sender: string; content: string }[]
): Promise<string> {
  const chatText = messages.map((m) => `${m.sender}: ${m.content}`).join('\n');

  const completion = await groq.chat.completions.create({
    model: 'llama-3.3-70b-versatile',
    messages: [
      {
        role: 'user',
        content: `Сделай краткое резюме этого чата (3-5 предложений). Выдели главные темы и итоги:\n\n${chatText}`,
      },
    ],
    max_tokens: 512,
  });

  return completion.choices[0]?.message?.content || 'Не удалось создать резюме.';
}

export async function translateText(text: string, targetLang: string): Promise<string> {
  const completion = await groq.chat.completions.create({
    model: 'llama-3.3-70b-versatile',
    messages: [
      {
        role: 'user',
        content: `Переведи следующий текст на ${targetLang}. Верни только перевод без пояснений:\n\n${text}`,
      },
    ],
    max_tokens: 512,
  });
  return completion.choices[0]?.message?.content || text;
}
