# Shader Studio (MSL Animator)

Shader Studio is a tool for animating MSL (Metal Shading Language) shaders. It provides a built-in generative AI feature for creating shaders from a text prompt. It can then export a QuickTime movie of the animation. It can save .metal files and export .mov files. The .metal file contains the prompt used to generate the shader. 


### Prerequisites

- MSL Animator requires Swift 5.7 or later.  
- Google AI Studio API Key
    - Sign up for a Google AI Studio account at https://aistudio.google.com
    - Get an API key from the API keys section
    - Set the API key in the shell environment (`~/.bashrc` or `~/.zshrc`):

```sh
export GEMINI_API_KEY=your_api_key
```

```sh
source ~/.bashrc
```

### Getting Started
Download and install Google Antigravity IDE from https://antigravity.google

Clone the repository:

```sh
git clone https://github.com/cerkit/shader_studio.git
```

Open the project folder in Antigravity IDE.

Ensure you have the Swift language Plugin installed.

Open the terminal:

`CTRL` + `~`

```sh
cd shader_studio
```

Build the app:

```sh
swift build
```

Run the app:

```sh
swift run
```


