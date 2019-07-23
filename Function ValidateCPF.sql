CREATE FUNCTION [dbo].[ValidateCPF] ( @RawCPF NUMERIC(11) ) RETURNS BIT AS  
BEGIN 
   DECLARE @CPF VARCHAR(11) 
   DECLARE @Digit INT, @Index INT, @Module INT 
   DECLARE @ChkSum1 INT, @ChkSum2 INT 
   DECLARE @ChkDigit1 INT, @ChkDigit2 INT 
  
   SELECT @Index = 1, @ChkSum1 = 0, @ChkSum2 = 0 
         
   SELECT @CPF = RIGHT('00000000000' + LTRIM(STR(@RawCPF, 11)), 11)  

   WHILE @Index <= 9 
   BEGIN 
       SET @Digit = CAST(SUBSTRING(@CPF, @Index, 1) AS INT) 
       SELECT @ChkSum1 = @ChkSum1 + ((11 - @Index) * @Digit), 
              @ChkSum2 = @ChkSum2 + ((12 - @Index) * @Digit) 
       SET @Index = @Index + 1 
   END 
   SET @Module = @ChkSum1 % 11 

   IF @Module < 2 
       SET @ChkDigit1 = 0 
   ELSE 
       SET @ChkDigit1 = 11 - @Module 
  
   SET @ChkSum2 = @ChkSum2 + (2 * @ChkDigit1) 
   SET @Module = @ChkSum2 % 11 
  
   IF @Module < 2 
       SET @ChkDigit2 = 0 
   ELSE 
       SET @ChkDigit2 = 11 - @Module 
  
   IF SUBSTRING(@CPF, 10, 1) = CAST(@ChkDigit1 AS varchar(1)) AND 
      SUBSTRING(@CPF, 11, 1) = CAST(@ChkDigit2 AS varchar(1)) 
       RETURN 1 
   RETURN 0 
END
GO