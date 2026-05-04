{{flutter_js}}
{{flutter_build_config}}

const loading = document.getElementById('loading');
if (loading) {
  loading.textContent = 'Fetching Social Sport Ladder files from web server...';
}

_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    if (loading) {
      loading.textContent = 'Initializing Flutter engine...';
    }

    const appRunner = await engineInitializer.initializeEngine();

    if (loading) {
      loading.textContent = 'Starting application... Almost there!';
    }

    await appRunner.runApp();
  },
});
