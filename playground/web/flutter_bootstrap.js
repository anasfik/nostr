{{flutter_js}}
{{flutter_build_config}}

const boot = document.getElementById('boot');
const bootStatus = document.getElementById('boot-status');
let appStarted = false;

function failBoot(message) {
  if (appStarted || !boot || !bootStatus) {
    return;
  }
  boot.classList.add('boot-error');
  bootStatus.textContent = message;
}

window.addEventListener('error', function () {
  failBoot('The playground failed to load. Check your connection, then reload. Home and docs links still work.');
});
window.addEventListener('unhandledrejection', function () {
  failBoot('The playground failed to load. Check your connection, then reload. Home and docs links still work.');
});

const bootTimeout = window.setTimeout(function () {
  failBoot('Loading is taking longer than expected. Reload, or open the docs while the network recovers.');
}, 30000);

_flutter.loader
  .load({
    config: {hostElement: document.getElementById('flutter-host')},
    onEntrypointLoaded: async function (engineInitializer) {
      if (bootStatus) {
        bootStatus.textContent = 'Starting the Flutter engine…';
      }
      const appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
      appStarted = true;
      window.clearTimeout(bootTimeout);
      if (boot) {
        window.requestAnimationFrame(function () {
          boot.remove();
        });
      }
    },
  })
  .catch(function () {
    window.clearTimeout(bootTimeout);
    failBoot('The playground failed to start. Reload to try again. Home and docs links still work.');
  });
