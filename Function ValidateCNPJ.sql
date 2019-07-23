CREATE FUNCTION [dbo].[ValidateCNPJ]( @RawCNPJ NUMERIC(14) ) RETURNS BIT AS
BEGIN
   DECLARE @CNPJ VARCHAR (14), @NewCNPJ VARCHAR(14), 
           @Factor1 VARCHAR(12), @Factor2 VARCHAR(13),
           @ChkSum INT, @i INT, @ChkDigit1 INT, @ChkDigit2 INT

   SELECT @i = 0, @ChkSum = 0, @ChkDigit1 = 0, @ChkDigit2 = 0

   SELECT @CNPJ = RIGHT('00000000000000' + LTRIM(STR(@RawCNPJ, 14)), 14),
          @NewCNPJ = LEFT(@CNPJ, 12)

   SELECT @Factor1 = '543298765432'  -- #1 - Factor Phase 1
   SELECT @Factor2 = '6543298765432' -- #2 - Factor Phase 2

   WHILE @i <= 12
   BEGIN
      SELECT @ChkSum = @ChkSum + CONVERT(INT, SUBSTRING(@NewCNPJ, @i, 1)) * CONVERT(INT, SUBSTRING(@Factor1, @i, 1))
      SELECT @i = @i + 1
   END

   SELECT @ChkSum = @ChkSum % 11

   IF (@ChkSum < 2)
      SELECT @ChkDigit1 = 0
   ELSE
      SELECT @ChkDigit1 = 11 - @ChkSum

   SELECT @NewCNPJ= @NewCNPJ + STR( @ChkDigit1, 1)

   SELECT @i = 0, @ChkSum = 0

   WHILE @i <= 13
   BEGIN
      SELECT @ChkSum = @ChkSum + CONVERT(INT, SUBSTRING(@NewCNPJ, @i, 1)) * CONVERT(INT, SUBSTRING(@Factor2, @i, 1))
      SELECT @i = @i + 1
   END

   SELECT @ChkSum = @ChkSum % 11

   IF (@ChkSum < 2)
      SELECT @ChkDigit2 = 0
   ELSE
      SELECT @ChkDigit2 = 11 - @ChkSum

   SELECT @NewCNPJ = @NewCNPJ + STR(@ChkDigit2, 1)

   IF (SUBSTRING(@CNPJ, 13, 1) = @ChkDigit1) AND (SUBSTRING(@CNPJ, 14, 1) = @ChkDigit2)
      RETURN 1
   
   RETURN 0
END
GO