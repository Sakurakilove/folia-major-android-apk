const { runAiConnectionTest, runAiJsonCompletion, runGeminiThemeCompletion,
    normalizeOpenAIChatCompletionsUrl, detectOpenAICompatibleProvider } = require('./electron/aiTextClient.cjs');
const { sanitizeDualTheme } = require('./shared/themeSanitizer.cjs');
const segmentation = require('./shared/lyricSegmentationPrompt.cjs');
const theme = require('./shared/themePrompt.cjs');

// Share the desktop prompts, validation and provider client with Android.
module.exports = ({ store, credentials, network }) => {
    const fetch = (url, options) => network.fetch(url, options, Boolean(store.get('USE_SYSTEM_PROXY_FOR_AI', false)));
    return ({
    async generateTheme(text, options = {}) {
        const systemPrompt = theme.buildThemeSystemPrompt(true);
        const sourcePrompt = theme.buildThemeSourcePrompt(text.slice(0, 2000), options.isPureMusic ?? false, options.songTitle);
        let result;
        if (store.get('AI_PROVIDER') === 'openai') {
            let content = await runAiJsonCompletion({ store, systemPrompt, sourcePrompt,
                schema: theme.THEME_JSON_SCHEMA, schemaName: theme.THEME_JSON_SCHEMA_NAME,
                customFetch: fetch, maxTokens: detectOpenAICompatibleProvider(normalizeOpenAIChatCompletionsUrl(store.get('OPENAI_API_URL'))) === 'openai'
                    ? theme.THEME_MAX_OUTPUT_TOKENS : 8192 });
            content = content.trim().replace(/^```(?:json)?\s*/, '').replace(/\s*```$/, '');
            result = sanitizeDualTheme(JSON.parse(content));
        } else {
            result = sanitizeDualTheme(await runGeminiThemeCompletion({ store, systemPrompt, sourcePrompt,
                responseSchema: theme.getGeminiResponseSchema(), customFetch: fetch }));
        }
        for (const mode of ['light', 'dark']) Object.assign(result[mode], { fontStyle: 'sans', animationIntensity: 'normal',
            provider: store.get('AI_PROVIDER') === 'openai' ? 'OpenAI Compatible (Local)' : 'Google Gemini (Local)' });
        return result;
    },
    async segmentLyrics(lines) {
        const content = await runAiJsonCompletion({ store, customFetch: fetch,
            systemPrompt: segmentation.buildSegmentationSystemPrompt(), sourcePrompt: segmentation.buildSegmentationSourcePrompt(lines),
            schema: segmentation.SEGMENTATION_JSON_SCHEMA, schemaName: segmentation.SEGMENTATION_SCHEMA_NAME,
            geminiGenerationConfig: segmentation.SEGMENTATION_GEMINI_GENERATION_CONFIG,
            maxTokens: segmentation.SEGMENTATION_MAX_OUTPUT_TOKENS, disableReasoning: true });
        return segmentation.parseSegmentationResponse(content, lines).boundaries;
    },
    async testAiConnection(payload) {
        const resolved = credentials.resolveTestApiKey(payload.provider, payload.apiKey, payload.apiUrl);
        if (resolved.error) return { ok: false, durationMs: 0, errorKind: 'config', error: resolved.error };
        const proxy = typeof payload.useSystemProxy === 'boolean' ? payload.useSystemProxy : Boolean(store.get('USE_SYSTEM_PROXY_FOR_AI', false));
        return runAiConnectionTest({ ...payload, apiKey: resolved.apiKey }, { customFetch: (url, options) => network.fetch(url, options, proxy) });
    },
});
};
