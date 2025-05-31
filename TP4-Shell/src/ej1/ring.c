#include <sys/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>

#include <sys/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>

#include <sys/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>

int main(int argc, char **argv)
{
	int start, n;
	// int buffer[1]; no need al final, uso int c directamente

	if (argc != 4)
	{
		printf("Uso: anillo <n> <c> <s> \n");
		exit(0);
	}

	n = atoi(argv[1]);
	int c = atoi(argv[2]);
	start = atoi(argv[3]);

	if (start < 0 || start >= n)
	{
		fprintf(stderr, "Start (el tercer input) debe estar entre 0 y n-1 (el primer input)\n");
		exit(1);
	}

	printf("Se crearán %i procesos, se enviará el valor %i desde proceso %i \n", n, c, start);

	int pipes[n][2];
	for (int i = 0; i < n; i++)
	{
		if (pipe(pipes[i]) == -1)
		{
			perror("pipe");
			exit(1);
		}
	}

	int parent_pipe[2];
	if (pipe(parent_pipe) == -1)
	{
		perror("pipe");
		exit(1);
	}

	for (int i = 0; i < n; i++)
	{
		pid_t pid = fork();
		if (pid < 0)
		{
			perror("fork");
			exit(1);
		}
		else if (pid == 0)
		{
			// Children: Close unrelated pipe ends
			for (int j = 0; j < n; j++)
			{
				if (j != i)
					close(pipes[j][0]); // Only read from pipe i
				if (j != (i + 1) % n)
					close(pipes[j][1]);
			}

			close(parent_pipe[0]);

			int value;
			read(pipes[i][0], &value, sizeof(int));
			value++;

			if ((i + 1) % n == start)
			{
				// Write al parent
				write(parent_pipe[1], &value, sizeof(int));
			}
			else
			{
				// Write al siguiente process
				write(pipes[(i + 1) % n][1], &value, sizeof(int));
			}

			// Close las pipes usadas y exit
			close(pipes[i][0]);
			close(pipes[(i + 1) % n][1]);
			close(parent_pipe[1]);
			exit(0);
		}
	}

	// El parent process
	for (int i = 0; i < n; i++)
	{
		close(pipes[i][0]); // Parent doesn
		if (i != start)
			close(pipes[i][1]);
	}
	close(parent_pipe[1]);

	write(pipes[start][1], &c, sizeof(int));
	close(pipes[start][1]);

	int final_value;
	read(parent_pipe[0], &final_value, sizeof(int));
	close(parent_pipe[0]);

	for (int i = 0; i < n; i++)
	{
		wait(NULL);
	}

	printf("Valor final recibido en el padre: %d\n", final_value);
	return 0;
}