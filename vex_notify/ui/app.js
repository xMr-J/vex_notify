(() => {
    'use strict';

    const resourceName =
        typeof GetParentResourceName === 'function'
            ? GetParentResourceName()
            : 'vex_notify';

    const state = {
        notifications: new Map(),
        activeChoice: null
    };

    const regions = {
        toast: document.getElementById('toast-region'),
        anchor: document.getElementById('anchor-region'),
        alert: document.getElementById('alert-region'),
        progress: document.getElementById('progress-region'),
        modal: document.getElementById('modal-region')
    };

    const presetMap = Object.freeze({
        default: {
            accent: '#B98A45',
            icon: '◆'
        },

        info: {
            accent: '#506B78',
            icon: 'ℹ'
        },

        success: {
            accent: '#607A49',
            icon: '✓'
        },

        warning: {
            accent: '#B17832',
            icon: '!'
        },

        error: {
            accent: '#8B3A32',
            icon: '×'
        },

        objective: {
            accent: '#B98A45',
            icon: '◆'
        },

        system: {
            accent: '#E7D7B1',
            icon: '★'
        }
    });

    function postNui(endpoint, payload = {}) {
        return fetch(
            `https://${resourceName}/${endpoint}`,
            {
                method: 'POST',

                headers: {
                    'Content-Type': 'application/json; charset=UTF-8'
                },

                body: JSON.stringify(payload)
            }
        ).catch(() => null);
    }

    function safeString(value, fallback = '') {
        return typeof value === 'string'
            ? value
            : fallback;
    }

    function safeDuration(value, fallback = 4000) {
        const parsed = Number(value);

        if (!Number.isFinite(parsed) || parsed <= 0) {
            return fallback;
        }

        return Math.max(
            100,
            Math.floor(parsed)
        );
    }

    function getPreset(meta) {
        const key =
            meta &&
            typeof meta.preset === 'string'
                ? meta.preset
                : 'default';

        return presetMap[key]
            || presetMap.default;
    }

    function createElement(tag, className = '') {
        const element = document.createElement(tag);

        if (className) {
            element.className = className;
        }

        return element;
    }

    function createPanel(payload, extraClass = '') {
        const meta =
            payload.meta &&
            typeof payload.meta === 'object'
                ? payload.meta
                : {};

        const preset = getPreset(meta);

        const panel = createElement(
            'article',
            `vex-panel ${extraClass}`.trim()
        );

        panel.dataset.notificationId = payload.id;

        panel.style.setProperty(
            '--accent',
            typeof meta.accent === 'string'
                ? meta.accent
                : preset.accent
        );

        const body = createElement(
            'div',
            'vex-panel__body'
        );

        const icon = createElement(
            'div',
            'vex-panel__icon'
        );

        icon.textContent =
            typeof meta.icon === 'string'
                ? meta.icon
                : preset.icon;

        const content = createElement(
            'div',
            'vex-panel__content'
        );

        if (
            typeof payload.title === 'string' &&
            payload.title.length > 0
        ) {
            const title = createElement(
                'h2',
                'vex-panel__title'
            );

            title.textContent = payload.title;

            content.appendChild(title);
        }

        const message = createElement(
            'p',
            'vex-panel__message'
        );

        message.textContent =
            safeString(payload.message);

        content.appendChild(message);

        body.append(
            icon,
            content
        );

        panel.appendChild(body);

        return {
            panel,
            message
        };
    }

    function activate(element) {
        requestAnimationFrame(() => {
            element.classList.add('is-visible');
        });
    }

    function notifyLifecycle(
        id,
        event
    ) {
        void postNui(
            'vex_notify:lifecycleEvent',
            {
                id,
                event
            }
        );
    }

    function destroyNotification(
        id,
        lifecycleEvent = null
    ) {
        const record =
            state.notifications.get(id);

        if (!record) {
            return;
        }

        if (record.timer) {
            clearTimeout(record.timer);
        }

        record.element.classList.add(
            'is-leaving'
        );

        state.notifications.delete(id);

        window.setTimeout(() => {
            record.element.remove();

            if (lifecycleEvent) {
                notifyLifecycle(
                    id,
                    lifecycleEvent
                );
            }
        }, 180);
    }

    function renderToast(payload) {
        const { panel } =
            createPanel(
                payload,
                'vex-toast'
            );

        regions.toast.appendChild(panel);

        const duration =
            safeDuration(
                payload.duration,
                4000
            );

        const timer =
            window.setTimeout(
                () => {
                    destroyNotification(
                        payload.id,
                        'expired'
                    );
                },
                duration
            );

        state.notifications.set(
            payload.id,
            {
                type: 'toast',
                element: panel,
                timer
            }
        );

        activate(panel);
    }

    function renderAnchor(payload) {
        // Single-slot behavior.
        for (
            const [id, record]
            of state.notifications.entries()
        ) {
            if (record.type === 'anchor') {
                destroyNotification(id);
            }
        }

        const { panel } =
            createPanel(
                payload,
                'vex-anchor'
            );

        regions.anchor.appendChild(panel);

        state.notifications.set(
            payload.id,
            {
                type: 'anchor',
                element: panel,
                timer: null
            }
        );

        activate(panel);
    }

    function renderAlert(payload) {
        // Single visible alert slot.
        for (
            const [id, record]
            of state.notifications.entries()
        ) {
            if (record.type === 'alert') {
                destroyNotification(id);
            }
        }

        const { panel } =
            createPanel(
                payload,
                'vex-alert'
            );

        regions.alert.appendChild(panel);

        const duration =
            safeDuration(
                payload.duration,
                6000
            );

        const timer =
            window.setTimeout(
                () => {
                    destroyNotification(
                        payload.id,
                        'expired'
                    );
                },
                duration
            );

        state.notifications.set(
            payload.id,
            {
                type: 'alert',
                element: panel,
                timer
            }
        );

        activate(panel);
    }

    function renderProgress(payload) {
        for (
            const [id, record]
            of state.notifications.entries()
        ) {
            if (record.type === 'progress') {
                destroyNotification(
                    id,
                    'cancelled'
                );
            }
        }

        const { panel, message } =
            createPanel(
                payload,
                'vex-progress'
            );

        const track = createElement(
            'div',
            'vex-progress__track'
        );

        const bar = createElement(
            'div',
            'vex-progress__bar'
        );

        track.appendChild(bar);
        panel.appendChild(track);

        const duration =
            safeDuration(
                payload.duration,
                5000
            );

        panel.style.setProperty(
            '--duration',
            `${duration}ms`
        );

        regions.progress.appendChild(panel);

        const timer =
            window.setTimeout(
                () => {
                    destroyNotification(
                        payload.id,
                        'completed'
                    );
                },
                duration
            );

        state.notifications.set(
            payload.id,
            {
                type: 'progress',
                element: panel,
                messageElement: message,
                timer
            }
        );

        activate(panel);

        requestAnimationFrame(() => {
            panel.classList.add(
                'is-running'
            );
        });
    }

    function closeChoice() {
        const choice =
            state.activeChoice;

        if (!choice) {
            return;
        }

        if (choice.timer) {
            clearTimeout(choice.timer);
        }

        if (choice.interval) {
            clearInterval(choice.interval);
        }

        choice.element.classList.remove(
            'is-visible'
        );

        regions.modal.classList.remove(
            'is-active'
        );

        window.setTimeout(() => {
            regions.modal.replaceChildren();
        }, 150);

        state.activeChoice = null;
    }

    function submitChoice(
        id,
        value,
        reason = 'selected'
    ) {
        if (
            !state.activeChoice ||
            state.activeChoice.id !== id ||
            state.activeChoice.resolved
        ) {
            return;
        }

        state.activeChoice.resolved = true;

        void postNui(
            'vex_notify:choiceResult',
            {
                id,
                value,
                reason
            }
        );

        closeChoice();
    }

    function renderChoice(payload) {
        if (state.activeChoice) {
            return;
        }

        const id =
            safeString(payload.id);

        if (!id) {
            return;
        }

        const backdrop =
            createElement(
                'div',
                'vex-modal-backdrop'
            );

        const modal =
            createElement(
                'section',
                'vex-choice'
            );

        modal.setAttribute(
            'role',
            'dialog'
        );

        modal.setAttribute(
            'aria-modal',
            'true'
        );

        const title =
            createElement(
                'h1',
                'vex-choice__title'
            );

        title.textContent =
            safeString(
                payload.title,
                'Notification'
            );

        const message =
            createElement(
                'p',
                'vex-choice__message'
            );

        message.textContent =
            safeString(
                payload.message
            );

        const buttonContainer =
            createElement(
                'div',
                'vex-choice__buttons'
            );

        const buttons =
            Array.isArray(payload.buttons)
                ? payload.buttons
                : [];

        for (const buttonData of buttons) {
            const button =
                createElement(
                    'button',
                    'vex-choice__button'
                );

            button.type = 'button';

            button.textContent =
                safeString(
                    buttonData.label,
                    'Select'
                );

            button.addEventListener(
                'click',
                () => {
                    submitChoice(
                        id,
                        buttonData.value,
                        'selected'
                    );
                }
            );

            buttonContainer.appendChild(
                button
            );
        }

        const countdown =
            createElement(
                'div',
                'vex-choice__countdown'
            );

        const timeout =
            safeDuration(
                payload.timeout,
                15000
            );

        const expiresAt =
            Date.now() + timeout;

        function updateCountdown() {
            const remaining =
                Math.max(
                    0,
                    expiresAt - Date.now()
                );

            countdown.textContent =
                `Response window: ${(
                    remaining / 1000
                ).toFixed(1)}s`;
        }

        modal.append(
            title,
            message,
            buttonContainer,
            countdown
        );

        regions.modal.replaceChildren(
            backdrop,
            modal
        );

        regions.modal.classList.add(
            'is-active'
        );

        updateCountdown();

        const interval =
            window.setInterval(
                updateCountdown,
                100
            );

        // This visual timeout mirrors transport timeout behavior.
        // Transport remains authoritative.
        const timer =
            window.setTimeout(
                () => {
                    if (
                        state.activeChoice &&
                        state.activeChoice.id === id
                    ) {
                        submitChoice(
                            id,
                            false,
                            'timeout'
                        );
                    }
                },
                timeout
            );

        state.activeChoice = {
            id,
            element: modal,
            timer,
            interval,
            resolved: false
        };

        requestAnimationFrame(() => {
            modal.classList.add(
                'is-visible'
            );
        });

        const firstButton =
            buttonContainer.querySelector(
                'button'
            );

        if (firstButton) {
            firstButton.focus();
        }
    }

    function renderNotification(payload) {
        if (
            typeof payload.id !== 'string' ||
            typeof payload.type !== 'string'
        ) {
            return;
        }

        switch (payload.type) {
            case 'toast':
                renderToast(payload);
                break;

            case 'anchor':
                renderAnchor(payload);
                break;

            case 'alert':
                renderAlert(payload);
                break;

            case 'progress':
                renderProgress(payload);
                break;

            case 'choice':
                renderChoice(payload);
                break;

            default:
                break;
        }
    }

    function updateNotification(payload) {
        if (typeof payload.id !== 'string') {
            return;
        }

        if (
            payload.op === 'cancel' ||
            payload.op === 'complete'
        ) {
            if (
                state.activeChoice &&
                state.activeChoice.id === payload.id
            ) {
                closeChoice();
                return;
            }

            destroyNotification(
                payload.id,
                payload.op === 'complete'
                    ? 'completed'
                    : 'cancelled'
            );

            return;
        }

        if (payload.op !== 'update') {
            return;
        }

        const record =
            state.notifications.get(
                payload.id
            );

        if (!record) {
            return;
        }

        if (
            record.messageElement &&
            typeof payload.message === 'string'
        ) {
            record.messageElement.textContent =
                payload.message;
        }
    }

    function reset() {
        for (
            const [id]
            of state.notifications.entries()
        ) {
            destroyNotification(id);
        }

        closeChoice();

        for (
            const region
            of Object.values(regions)
        ) {
            region.replaceChildren();
        }

        state.notifications.clear();
        state.activeChoice = null;
    }

    window.addEventListener(
        'message',
        (event) => {
            const payload = event.data;

            if (
                !payload ||
                typeof payload !== 'object'
            ) {
                return;
            }

            switch (payload.action) {
                case 'notify':
                    renderNotification(payload);
                    break;

                case 'notifyUpdate':
                    updateNotification(payload);
                    break;

                case 'reset':
                    reset();
                    break;

                default:
                    break;
            }
        }
    );
})();