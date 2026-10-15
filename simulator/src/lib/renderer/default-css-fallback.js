/**
 * Bundled copy of gbaduo/app/src/main/assets/companion/default.css, used only when the
 * live file can't be read (e.g. the gbaduo repo isn't checked out as a sibling directory).
 * Can go stale — api/default-css/+server.js always prefers the live file and only falls
 * back to this with a `source: "fallback"` flag the UI surfaces as a warning.
 */
export const DEFAULT_CSS_FALLBACK = `
:root {
    width: 100%;
    height: 100%;
    color: #ffffff;
    font-size: 14px;
}

column, list {
    display: flex;
    flex-direction: column;
}

row {
    display: flex;
    flex-direction: row;
    align-items: flex-start;
}

box {
    display: flex;
    flex-direction: column;
}

image {
    width: 32px;
    height: 32px;
    object-fit: contain;
    image-rendering: pixelated;
}

spacer {
    width: 8px;
    height: 8px;
    flex-shrink: 0;
}

bar {
    display: stack;
    height: 12px;
    background-color: rgba(108, 74, 182, 0.3);
    accent-color: #6c4ab6;
}

bar > fill {
    position: absolute;
    left: 0;
    top: 0;
    bottom: 0;
}

bar > label {
    align-self: center;
    justify-self: center;
    font-size: 10px;
    white-space: nowrap;
}

tabs {
    display: flex;
    flex-direction: column;
}

tab-bar {
    display: flex;
    flex-direction: row;
}

tab {
    padding: 8px 12px;
    color: #888888;
}

tab:active {
    color: #ffffff;
}

tab-content {
    display: stack;
    place-items: stretch;
    flex: 1 1 auto;
}

empty {
    color: #888888;
}
`;
