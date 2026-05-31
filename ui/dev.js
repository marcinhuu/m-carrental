// Browser dev frame only. In LB Phone (invokeNative) we keep the default DOM — same as CarSpot.
window.addEventListener('load', () => {
    const phoneWrapper = document.getElementById('phone-wrapper');
    const app = phoneWrapper.querySelector('.app');

    if (window.invokeNative) {
        document.documentElement.classList.add('in-phone');
        phoneWrapper.parentNode.insertBefore(app, phoneWrapper);
        phoneWrapper.parentNode.removeChild(phoneWrapper);
        return;
    }

    document.documentElement.classList.add('dev-mode');

    const createFrame = (children) => {
        const frame = document.createElement('div');
        frame.classList.add('phone-frame');
        const notch = document.createElement('div');
        notch.classList.add('phone-notch');
        const indicator = document.createElement('div');
        indicator.classList.add('phone-indicator');
        const time = document.createElement('div');
        time.classList.add('phone-time');
        const date = new Date();
        time.innerText = date.getHours().toString().padStart(2, '0') + ':' + date.getMinutes().toString().padStart(2, '0');
        setInterval(() => {
            const d = new Date();
            time.innerText = d.getHours().toString().padStart(2, '0') + ':' + d.getMinutes().toString().padStart(2, '0');
        }, 1000);
        const phoneContent = document.createElement('div');
        phoneContent.classList.add('phone-content');
        phoneContent.appendChild(children);
        frame.appendChild(notch);
        frame.appendChild(phoneContent);
        frame.appendChild(indicator);
        frame.appendChild(time);
        return frame;
    };

    const devWrapper = document.createElement('div');
    devWrapper.classList.add('dev-wrapper');
    devWrapper.style.display = 'block';
    const frame = createFrame(app);
    devWrapper.appendChild(frame);
    phoneWrapper.parentNode.insertBefore(devWrapper, phoneWrapper);
    phoneWrapper.parentNode.removeChild(phoneWrapper);
    document.body.style.visibility = 'visible';
});
