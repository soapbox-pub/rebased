# Theming your instance

To add a custom theme to your instance, you'll first need to get a custom theme, upload it to the server, make it available to the instance and eventually you can set it as default.

## Getting a custom theme

### Create your own theme

* You can create your own theme using the Pleroma FE by going to settings (gear on the top right) and choose the Theme tab. Here you have the options to create a personal theme.
* To download your theme, you can do Save preset
* If you want to upload a theme to customise it further, you can upload it using Load preset

This will only save the theme for you personally. To make it available to the whole instance, you'll need to upload it to the server.

### Get an existing theme

* You can download a theme from another instance by going to that instance, go to settings and make sure you have the theme selected that you want. Then you can do Save preset to download it.
* You can also find and download custom themes at <https://plthemes.vulpes.one/>

## Adding the custom theme to the instance

### Upload the theme to the server

Themes can be found in the [static directory](static_dir.md). Create `STATIC-DIR/static/themes/` if needed and copy your theme there. Next you need to add an entry for your theme to `STATIC-DIR/static/styles.json`. If you use a from source installation, you'll first need to copy the file from `priv/static/static/styles.json`.

Example of `styles.json` where we add our own `my-awesome-theme.json`
```json
{
  "pleroma-dark": [ "Pleroma Dark", "#121a24", "#182230", "#b9b9ba", "#d8a070", "#d31014", "#0fa00f", "#0095ff", "#ffa500" ],
  "pleroma-light": [ "Pleroma Light", "#f2f4f6", "#dbe0e8", "#304055", "#f86f0f", "#d31014", "#0fa00f", "#0095ff", "#ffa500" ],
  "classic-dark": [ "Classic Dark", "#161c20", "#282e32", "#b9b9b9", "#baaa9c", "#d31014", "#0fa00f", "#0095ff", "#ffa500" ],
  "bird": [ "Bird", "#f8fafd", "#e6ecf0", "#14171a", "#0084b8", "#e0245e", "#17bf63", "#1b95e0", "#fab81e"],
  "ir-black": [ "Ir Black", "#000000", "#242422", "#b5b3aa", "#ff6c60", "#FF6C60", "#A8FF60", "#96CBFE", "#FFFFB6" ],
  "monokai": [ "Monokai", "#272822", "#383830", "#f8f8f2", "#f92672", "#F92672", "#a6e22e", "#66d9ef", "#f4bf75" ],

  "redmond-xx": "/static/themes/redmond-xx.json",
  "redmond-xx-se": "/static/themes/redmond-xx-se.json",
  "redmond-xxi": "/static/themes/redmond-xxi.json",
  "breezy-dark": "/static/themes/breezy-dark.json",
  "breezy-light": "/static/themes/breezy-light.json",
  "mammal": "/static/themes/mammal.json",
  "my-awesome-theme": "/static/themes/my-awesome-theme.json"
}
```

Now you'll already be able to select the theme in Pleroma FE from the drop-down. You don't need to restart Pleroma because we only changed static served files. You may need to refresh the page in your browser. You'll notice however that the theme doesn't have a name, it's just an empty entry in the drop-down.

### Give the theme a name

When you open one of the themes that ship with Pleroma, you'll notice that the json has a `"name"` key. Add a key-value pair to your theme where the key name is `"name"` and the value the name you want to give your theme. After this you can refresh te page in your browser and the name should be visible in the drop-down.

Example of `my-awesome-theme.json` where we add the name "My Awesome Theme"
```json
{
  "_pleroma_theme_version": 2,
  "name": "My Awesome Theme",
  "theme": {}
}
```

### Set as default theme

Now we can set the new theme as default in the [Pleroma FE configuration](General-tips-for-customizing-Pleroma-FE.md).

Example of adding the new theme in the back-end config files
```elixir
config :pleroma, :frontend_configurations,
  pleroma_fe: %{
    theme: "my-awesome-theme"
  }
```

If you added it in the back-end configuration file, you'll need to restart your instance for the changes to take effect. If you don't see the changes, it's probably because the browser has cached the previous theme. In that case you'll want to clear browser caches. Alternatively you can use a private/incognito window just to see the changes.

