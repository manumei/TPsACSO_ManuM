#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>
#include <string.h>
#include <errno.h>
#include <ctype.h>

#define MAX_COMMANDS 201
#define MAX_ARGS 65 // para que pase el test popular xd (64 args + NULL + comando)

// Helper: trim surrounding quotes (e.g. "hola" -> hola)
char *strip_quotes(char *arg)
{
    size_t len = strlen(arg);
    if (len >= 2 && (arg[0] == '"' || arg[0] == '\''))
    {
        if (arg[len - 1] == arg[0])
        {
            arg[len - 1] = '\0';
            return arg + 1;
        }
    }
    return arg;
}

// Helper: parse arguments respecting quotes
void parse_args(const char *input, char **argv, int *argc)
{
    *argc = 0;
    const char *p = input;
    while (*p)
    {
        while (isspace(*p))
            p++; // skip spaces

        if (*p == '\0')
            break;

        char *arg = malloc(256);
        int in_quote = 0;
        char quote_char = '\0';
        int i = 0;

        while (*p && (in_quote || (!isspace(*p))))
        {
            if (!in_quote && (*p == '"' || *p == '\''))
            {
                in_quote = 1;
                quote_char = *p++;
                continue;
            }

            if (in_quote && *p == quote_char)
            {
                in_quote = 0;
                p++;
                break;
            }

            arg[i++] = *p++;
        }

        arg[i] = '\0';

        if (in_quote)
        {
            fprintf(stderr, "Error: comillas sin cerrar\n");
            exit(1);
        }

        argv[*argc] = strip_quotes(arg);
        (*argc)++;

        if (*argc >= MAX_ARGS)
        {
            fprintf(stderr, "Error: se excedió el número máximo de argumentos (%d)\n", MAX_ARGS);
            exit(1);
        }
    }
    argv[*argc] = NULL;
}

int main()
{
    char command[4096];
    char *commands[MAX_COMMANDS];
    int command_count = 0;

    while (1)
    {
        if (isatty(STDIN_FILENO))
        {
            printf("Shell> ");
        }

        /*Reads a line of input from the user from the standard input (stdin) and stores it in the variable command */
        fgets(command, sizeof(command), stdin);

        /* Removes the newline character (\n) from the end of the string stored in command, if present.
           This is done by replacing the newline character with the null character ('\0').
           The strcspn() function returns the length of the initial segment of command that consists of
           characters not in the string specified in the second argument ("\n" in this case). */
        command[strcspn(command, "\n")] = '\0';

        // If exit
        if (strcmp(command, "exit") == 0)
        {
            break;
        }

        // Que no haya pipes al principio o al final (invalido)
        if (command[0] == '|' || command[strlen(command) - 1] == '|')
        {
            fprintf(stderr, "Error: comando no puede comenzar ni terminar con '|'\n");
            continue;
        }

        if (strstr(command, "||") != NULL)
        {
            fprintf(stderr, "Error: uso inválido de '||'\n");
            continue;
        }

        /* Tokenizes the command string using the pipe character (|) as a delimiter using the strtok() function.
           Each resulting token is stored in the commands[] array.
           The strtok() function breaks the command string into tokens (substrings) separated by the pipe character |.
           In each iteration of the while loop, strtok() returns the next token found in command.
           The tokens are stored in the commands[] array, and command_count is incremented to keep track of the number of tokens found. */
        command_count = 0;
        char *token = strtok(command, "|");
        while (token != NULL)
        {
            // Skip espacios al principio o final
            while (*token == ' ')
                token++;
            if (*token == '\0')
            {
                fprintf(stderr, "Error: comando vacío entre pipes\n");
                command_count = -1; // invalid
                break;
            }
            commands[command_count++] = token;
            token = strtok(NULL, "|");
        }

        if (command_count == -1)
            continue;

        if (command_count >= MAX_COMMANDS)
        {
            fprintf(stderr, "Error: se excedió el número máximo de comandos encadenados (%d)\n", MAX_COMMANDS - 1);
            continue;
        }

        // double pipes invalid
        if (strstr(command, "||") != NULL)
        {
            fprintf(stderr, "Error: uso inválido de '||'\n");
            continue;
        }

        int pipefds[2 * (command_count - 1)];
        for (int i = 0; i < command_count - 1; i++)
        {
            if (pipe(pipefds + i * 2) < 0)
            {
                perror("pipe");
                exit(EXIT_FAILURE);
            }
        }

        for (int i = 0; i < command_count; i++)
        {
            pid_t pid = fork();
            if (pid < 0)
            {
                perror("fork");
                exit(EXIT_FAILURE);
            }

            if (pid == 0)
            {
                // Set input pipe
                if (i != 0)
                {
                    if (dup2(pipefds[(i - 1) * 2], 0) < 0)
                    {
                        perror("dup2 input");
                        exit(EXIT_FAILURE);
                    }
                }

                // Set output pipe
                if (i != command_count - 1)
                {
                    if (dup2(pipefds[i * 2 + 1], 1) < 0)
                    {
                        perror("dup2 output");
                        exit(EXIT_FAILURE);
                    }
                }

                // child close
                for (int j = 0; j < 2 * (command_count - 1); j++)
                {
                    close(pipefds[j]);
                }

                char *argv[64];
                int argc;
                parse_args(commands[i], argv, &argc);

                if (argc == 0)
                {
                    fprintf(stderr, "Error: comando vacío\n");
                    exit(1);
                }

                // Execute
                execvp(argv[0], argv);
                fprintf(stderr, "Error ejecutando comando '%s': %s\n", argv[0], strerror(errno));
                exit(EXIT_FAILURE);
            }
        }

        // parent close
        for (int i = 0; i < 2 * (command_count - 1); i++)
        {
            close(pipefds[i]);
        }

        for (int i = 0; i < command_count; i++)
        {
            wait(NULL);
        }
    }

    return 0;
}
