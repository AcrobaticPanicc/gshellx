# README

## GShellX 💻

A Python-based CLI app powered by OpenAI's GPT-3.5-turbo model to generate responses to user prompts, with a specific focus on generating shell commands and scripts.
It is interactive and supports single command execution, pre-set prompts, and maintaining a history of prompts and responses.

### Features 🚀

- [x] **Generate CLI Commands:** Generate shell commands with a description in free language of what the command should do.
- [x] **Execute Generated Commands:** Allows immediate execution of the generated command.
- [x] **Interactive Mode:** Allows entering prompts and commands on the fly.
- [x] **History:** Keeps a history of the prompts and responses for future reference.
- [x] **Command Editing:** Edit the generated command, providing greater flexibility and control over the command execution.
- [x] **Rich Text Output:** Enhanced console output experience that highlights code blocks in the responses.

### Installation Instructions 📥

#### Prerequisites

- Python 3.6+
- OpenAI API key

#### Configuration 🔧

GShellX requires an OpenAI key to function, which should be set as an environment variable `OPENAI_KEY`.
Please refer to the OpenAI API profile to obtain your API key.

#### Installation

```shell
pip install gshellx
```

### Examples 📖

1. With a prompt (-p / --prompt):
   
   ```shell
   $ gsx --prompt "simple Python HTTP server with Flask."
   ```

   ``` python
   from flask import Flask
   
   # Create the Flask application
   app = Flask(__name__)
   
   # Define the route and handler for the root URL
   @app.route('/')
   def hello():
      return 'Hello, World!'
   
   # Start the Flask application
   if __name__ == '__main__':
      app.run()
   ```

2. With a command (-c / --cmd):

   ``` shell
   $ gsx --cmd "find all files larger than 3 megabytes in the current directory recursively"
   -> find . -type f -size +3M
   ```

3. Interactive Mode (-i / --interactive):
   <pre>
     <code>
   ➜ <span style="color:#90BE6D">gsx -i</span>

   <span style="color:#90BE6D">Enter a prompt:</span> command: display the top 10 processes sorted by memory usage

   <span style="color:#90BE6D">⠸ Processing...</span>

   <span style="color:#90BE6D">The command is:</span> top -o mem -l 1 -n 10 -stats pid,command,mem -l 1 | awk '$3 > 1 {print $0}'

   Do you want to execute this command? (y/n) or edit (e): y

   Output:
   10 PID    COMMAND          MEM
   11 54499* pycharm          4004M
   12 65519* ScreenX          2760M
   13 75199* Sublime Text     1973M
   14 86418* Finder           1815M
   15 454*   WindowServer     1461M
   16 3435*  Raycast          861M
   17 33109* Brave Browser    842M
   18 25102* Brave Browser    658M
   19 77155* Brave Browser    389M
   20 23415* Brave Browser    335M

   <span style="color:#90BE6D">Enter a prompt:</span>
     </code>
   </pre>

### Code Structure 📂

- `config.py`: Contains the configuration for the OpenAI API like the API key and headers.
- `openai_api.py`: Contains the logic for making requests to the OpenAI API.
- `prompts.py`: Contains the prompts used for generating shell commands.
- `shell_utils.py`: Contains utility functions for loading and saving history, printing history, and executing shell commands.
- `main.py`: The main entry point of the application. It uses click to parse command-line arguments and handles the flow of the application.

### Security Considerations ⚠️

The app has the potential to execute shell commands, which comes with inherent security risks.
Please review all generated commands carefully before choosing to execute them, and avoid running commands that you don't fully understand.

### Contributing 🤝

If you'd like to contribute to the development of this tool, please feel free to fork the repository, make your changes, and create a pull request.

### Future Work 💡

Future updates can potentially include additional interactive features, improved command generation, integration with other language models or APIs, and more.

### Disclaimer ⚠️

This app is developed for demonstration purposes and is not officially associated with or endorsed by OpenAI.

### License 📜

The project is released under [MIT License](LICENSE).
