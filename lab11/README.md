# Laboratório 11

## Questão 01
De início, é necessário conhecer os sinais de controle do registrador SP:

- INC - Incrementa o valor atual de SP de 1.  
    - SP[15...0] <= SP[15...0] + 1
- DEC - Decrementa o valor atual de SP de 1.  
    - SP[15...0] <= SP[15...0] - 1
- LH - Carrega o barramento de dados na parte alta de SP. 
    - SP[15...8] <= D[7...0]
- LL - Carrega o barramento de dados na parte baixa de SP.
    - SP[7...0] <= D[7...0]
- EHD - Coloca no barramento de dados a parte alta de SP.
    - D[7...0] <= SP[15...8]
- ELD - Coloca no barramento de dados a parte baixa de SP.
    - D[7...0] <= SP[7...0]
- EEA - Coloca no barramento de endereços o valor de SP.
    - A[15...0] <= SP[15...0]

Dentro do registrador SP, existem 4 circuitos integrados contadores em que cada um armazena 4 bits. Os sinais de controle LH e LL estão conectados em cada par de contador. Além disso, os sinais de INC e de DEC estão conectados apenas no primeiro contador, o qual transmitirá os sinais de INC ou de DEC para o segundo contador por meio dos sinais TCU ou TCD, respectivamente. De forma semelhante, o segundo contador transmitirá os sinais de TCU ou TCD para incrementar ou decrementar, respectivamente, o terceiro contador. Analogamente para o terceiro contador e o quarto contador. Portanto, é possível obter todos os números de 16 bits com essa arquitetura.

Os 16 bits que saem dos contadores 74HC193, se conectam nos pares de circuitos 74HC241, em que cada par de circuitos possui 16 bits de entrada. Os pares de circuitos funcionam como _buffer_ para a saída do registrador PC em determinados barramentos. Dessa forma, se é desejado que o barramento de endereços receba o valor de SP, então basta o sinal EEA ser alto que os dois circuitos integrados irão transmitir os dados. Caso contrário, os pares de 74HC241 ficam em 3-state. De forma análoga, é possível enviar a parte alta ou a parte baixa de SP para o barramento de dados. Note que os sinais ELD e EHD estão conectados em dois circuitos 74HC241, um sinal em cada circuito.

O restante do circuito interno do registrador SP contém portas OR de duas entradas que identificam se o valor do registrador SP é zero ou não é zero.
## Questão 02
No multiplexador de condições, tem-se `S0` alto e as demais chaves baixas devido aos valores de `C3`, `C2` e `C1`. Dessa forma, o Multiplexador de Condições passa o valor do `CARRY`.

Como os sinais `A1` e `A0` são altos, então os valores das chaves no Multiplexador de Microendereços será `S0S1 = 00` para `CARRY = 0` ou `S0S1 = 11` para `CARRY = 1`. 

- Quando `CARRY = 1`, então o Multiplexador de Endereços seleciona o próximo microendereço. `Saída = p`

- Quando `CARRY = 0`, então o Multiplexador de Endereços seleciona a saída do Micro PC. `Saída = a`

## Questão 03 à 06
A implementação das funções pedidas estão no arquivo dentro da pasta `TESTPROGS`. O arquivo `MP8Complex.txt` contém a implementação da função `LONGSUB` a nível de microprogramação, a qual estava em branco inicialmente.