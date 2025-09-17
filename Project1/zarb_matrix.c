#include <stdio.h>

#define MAX 10

int main() {
    int A[MAX][MAX], B[MAX][MAX], C[MAX][MAX] = {0};
    int rowA, colA, rowB, colB;

    
    printf("Enter rows and columns for matrix A: ");
    scanf("%d %d", &rowA, &colA);

    printf("Enter rows and columns for matrix B: ");
    scanf("%d %d", &rowB, &colB);

    if (colA != rowB) {
        printf("Matrix multiplication not possible.\n");
        return 1;
    }

    printf("Enter elements of matrix A:\n");
    for (int i = 0; i < rowA; i++) {
        for (int j = 0; j < colA; j++) {
            scanf("%d", &A[i][j]);
        }
    }

    
    printf("Enter elements of matrix B:\n");
    for (int i = 0; i < rowB; i++) {
        for (int j = 0; j < colB; j++) {
            scanf("%d", &B[i][j]);
        }
    }

    
    for (int i = 0; i < rowA; i++) {
        for (int j = 0; j < colB; j++) {
            int sum = 0;
            for (int k = 0; k < colA; k++) {
                int a = A[i][k], b = B[k][j];
                asm volatile(
                    "mac %[res], %[op1], %[op2]\n\t"
                    : [res] "+r" (sum)
                    : [op1] "r" (a), [op2] "r" (b)
                );
            }
            C[i][j] = sum;
        }
    }

   
    printf("Resulting matrix C:\n");
    for (int i = 0; i < rowA; i++) {
        for (int j = 0; j < colB; j++) {
            printf("%d ", C[i][j]);
        }
        printf("\n");
    }

    return 0;
}

