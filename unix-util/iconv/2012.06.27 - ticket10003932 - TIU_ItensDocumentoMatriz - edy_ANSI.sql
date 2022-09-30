DROP TRIGGER TIU_ItensDocumentoMatriz
GO

--2013.06.27 - ticket30002309 - TIU_ItensDocumentoMatriz - edy.sql
CREATE TRIGGER [dbo].[TIU_ItensDocumentoMatriz] ON [dbo].[ItensDocumento]
	FOR INSERT, UPDATE
AS BEGIN
	SET NOCOUNT ON
	SET ANSI_WARNINGS OFF

	/*
	 if @@NESTLEVEL >1 BEGIN
		return
	 END
	*/

	DECLARE @SEQ INT, @SEQID INT, @ACRESCIMOS FLOAT, @DESCONTOS FLOAT, @VALOR FLOAT, @TIPODOC INT,
		@FRETE FLOAT, @VALORCOFINS NUMERIC(18,2), @VALORPIS NUMERIC(18,2), @VALORISSQN NUMERIC(18,2),
		@VALORIPI NUMERIC(18,2), @TIPOISENTOOUTROS CHAR(1), @CFOPITEM int, @SeqMatriz int,
		@IncideIPI char(1), @IncidePIS char(1), @IncideCOFINS char(1), @IncideISS char(1), @Matriz char(1),
		@BaseICMS NUMERIC(18,2), @BaseIPI NUMERIC(18,2), @BaseISSQN NUMERIC(18,2), @BaseSubst NUMERIC(18,2),
		@ValorSubst NUMERIC(18,2), @despesa NUMERIC(18,2), @Seguro NUMERIC(18,2), @VALORICMS NUMERIC(18,2),
		@CSLL NUMERIC(18,2), @IRPJ NUMERIC(18,2), @DifICMS NUMERIC(18,2), @ValorInstOut NUMERIC(18,2), @ValorBruto FLOAT,
		@TotalOutros NUMERIC(18,2), @TotalIsento NUMERIC(18,2), @CodSped Char(2), @MAT Integer, @SomarFrete Char(1),
		@SomarFreteVlr Float, @ValorContabVlrLiq CHAR(1), @ValorItem Numeric(18,2), @IPIMatriz VarChar(1)

		SELECT @IPIMatriz = P.ValorIpiMatriz FROM INSERTED JOIN Documentos D ON D.Sequencial = INSERTED.Sequencial
				JOIN Pessoas P on D.Empresa = P.codigo

	IF (SELECT TOP 1 Isnull(D.TipoOrigem,'D') FROM INSERTED JOIN Documentos D ON D.Sequencial = INSERTED.Sequencial) <> 'R' BEGIN

		SELECT @MAT = INSERTED.PRODUTO,@SEQID = INSERTED.SEQID, @SEQ=INSERTED.SEQUENCIAL, @Matriz = IsNull(O.MATRIZ,'N'),
		@SomarFrete = IsNull(O.SomarFreteNF,'N'), @TIPODOC = D.TIPODOC, @ValorContabVlrLiq = O.ValorContabVlrLiq
		FROM DOCUMENTOS D JOIN INSERTED ON INSERTED.SEQUENCIAL=D.SEQUENCIAL
		JOIN OPERACOES O ON D.TIPOOPERACAO = O.SEQUENCIAL
		
		IF @MATRIZ = 'S' BEGIN

		--CALCULOS ITENS DOCUMENTO 
			Select @ACRESCIMOS = 0, @DESCONTOS = 0
					
			SELECT TOP 1 @SeqMatriz = ISNULL(I.SeqMatrizTrib,0), @TIPOISENTOOUTROS = IsNull(IsentosOutros,'')		
			FROM ITENSDOCUMENTO I LEFT JOIN ConfigTributos C ON I.SeqMatrizTrib = C.Sequencial WHERE I.SEQID=@SEQID 			
				
			SELECT @IncideIPI = ISNULL(C.IncideIPI,'N'), @IncidePIS= ISNULL(C.IncidePIS,'N'), @IncideCOFINS= ISNULL(C.IncideCOFINS,'N'),
			@IncideISS = ISNULL(C.IncideISS,'N'), @VALORIPI = ISNULL(VALORIPI,0), @VALORISSQN = ISNULL(VALORISSQN,0), @VALORPIS = ISNULL(VALORPIS,0),
			@VALORCOFINS = ISNULL(VALORCOFINS,0), @ValorItem = ISNULL(Valor,0)
			FROM ConfigTributos C Join ItensDocumento I ON C.Sequencial = I.SeqMatrizTrib
			WHERE I.SEQID=@SEQID
			if @ipimatriz='I' Begin
			  set @ValorItem = Null
			end
			    
			--IPI
			IF @IncideIPI = 'A' BEGIN
				SELECT @ACRESCIMOS = @ACRESCIMOS+@VALORIPI
			END ELSE IF @IncideIPI = 'S' BEGIN
				SELECT @DESCONTOS = @DESCONTOS+@VALORIPI
			END
			--PIS
			IF @IncidePIS = 'A' BEGIN
				SELECT @ACRESCIMOS = @ACRESCIMOS+@VALORPIS
			END ELSE IF @IncidePIS = 'S' BEGIN
				SELECT @DESCONTOS = @DESCONTOS+@VALORPIS
			END
			--ISSQN
			IF @IncideISS = 'A' BEGIN
				SELECT @ACRESCIMOS = @ACRESCIMOS+@VALORISSQN
			END ELSE IF @IncideISS = 'S' BEGIN
				SELECT @DESCONTOS = @DESCONTOS+@VALORISSQN
			END		
			--COFINS
			IF @IncideCOFINS = 'A' BEGIN
				SELECT @ACRESCIMOS = @ACRESCIMOS+@VALORCOFINS
			END ELSE IF @IncideCOFINS = 'S' BEGIN
				SELECT @DESCONTOS = @DESCONTOS+@VALORCOFINS
			END	
		
			
			SELECT @ValorInstOut = (ISNULL((VALOR),0)+ISNULL((VSub),0))- ISNULL((BaseICMSITEM),0) , @Frete = ISNULL(Frete,0)
			FROM ITENSDOCUMENTO WHERE SEQID = @SEQID
		    
		    IF @SomarFrete = 'S' BEGIN
				SELECT @SomarFreteVlr = @Frete
			END ELSE BEGIN
				SELECT @SomarFreteVlr = 0
			END		    
		    
		    
		    IF UPDATE(QTD) OR UPDATE(PcoUnit) OR UPDATE(Acrescimo) OR UPDATE(Frete) or UPDATE(Seguro) or 
			   UPDATE(Despesa) or UPDATE(Desconto) BEGIN
		    					
				UPDATE ITENSDOCUMENTO SET 		
				OutrosICMSItem = (CASE WHEN (@TIPOISENTOOUTROS = 'O') and ((@ValorInstOut+@ACRESCIMOS)>@DESCONTOS) THEN
				@ValorInstOut+@ACRESCIMOS-@DESCONTOS  ELSE 0 END),
				IsentoICMSITem = (CASE WHEN (@TIPOISENTOOUTROS = 'I') and ((@ValorInstOut+@ACRESCIMOS)>@DESCONTOS) THEN 
				@ValorInstOut+@ACRESCIMOS-@DESCONTOS ELSE 0 END),
				
				Valor = (Qtd*PcoUnit) + Isnull(Acrescimo,0) + @SomarFreteVlr + Isnull(Seguro,0) + Isnull(Despesa,0) + @ACRESCIMOS - (Isnull(Desconto,0) + @DESCONTOS)
						
				
				WHERE SEQID=@SEQID 							
			END
		
		-- FIM DO ITENS DOCUMENTO *
		
			Select @ACRESCIMOS = 0, @DESCONTOS = 0
			DECLARE CalcDescontos CURSOR FOR
				
				SELECT ISNULL(C.IncideIPI,'N'),ISNULL(C.IncidePIS,'N'),ISNULL(C.IncideCOFINS,'N'),
				ISNULL(C.IncideISS,'N'),ISNULL(VALORIPI,0),ISNULL(VALORISSQN,0),ISNULL(VALORPIS,0),
				ISNULL(VALORCOFINS,0)
				FROM ConfigTributos C Join ItensDocumento I ON C.Sequencial = I.SeqMatrizTrib
				WHERE I.SEQUENCIAL=@SEQ
			    
			OPEN CalcDescontos 
				FETCH NEXT FROM CalcDescontos INTO @IncideIPI,@IncidePIS,@IncideCOFINS,@IncideISS,
												   @VALORIPI,@VALORISSQN,@VALORPIS,@VALORCOFINS	
				WHILE @@Fetch_Status <> -1 BEGIN
					--IPI
					IF @IncideIPI = 'A' BEGIN
						SELECT @ACRESCIMOS = @ACRESCIMOS+@VALORIPI
					END ELSE IF @IncideIPI = 'S' BEGIN
						SELECT @DESCONTOS = @DESCONTOS+@VALORIPI
					END

					--PIS
					IF @IncidePIS = 'A' BEGIN
						SELECT @ACRESCIMOS = @ACRESCIMOS+@VALORPIS
					END ELSE IF @IncidePIS = 'S' BEGIN
						SELECT @DESCONTOS = @DESCONTOS+@VALORPIS
					END
					--ISSQN
					IF @IncideISS = 'A' BEGIN
						SELECT @ACRESCIMOS = @ACRESCIMOS+@VALORISSQN
					END ELSE IF @IncideISS = 'S' BEGIN
						SELECT @DESCONTOS = @DESCONTOS+@VALORISSQN
					END		
					--COFINS
					IF @IncideCOFINS = 'A' BEGIN
						SELECT @ACRESCIMOS = @ACRESCIMOS+@VALORCOFINS
					END ELSE IF @IncideCOFINS = 'S' BEGIN
						SELECT @DESCONTOS = @DESCONTOS+@VALORCOFINS
					END	
				FETCH NEXT FROM CalcDescontos INTO @IncideIPI,@IncidePIS,@IncideCOFINS,@IncideISS,
												   @VALORIPI,@VALORISSQN,@VALORPIS,@VALORCOFINS 
				END
			CLOSE CalcDescontos 
			DEALLOCATE CalcDescontos 

			SELECT @CFOPITEM = 0
			SELECT TOP 1 @CFOPITEM = CFOPITEM FROM ITENSDOCUMENTO I WHERE I.SEQUENCIAL=@SEQ AND CFOPITEM IS NOT NULL	
			
			SELECT @CFOPITEM = CASE WHEN ISNULL(@CFOPITEM, 0) = 0 THEN CFOP ELSE @CFOPITEM END,
				@CSLL= ISNULL(CSLL,0),
				@IRPJ= ISNULL(irpj,0)
			FROM DOCUMENTOS WHERE SEQUENCIAL = @SEQ
			
			SELECT @VALOR= ISNULL(SUM(round(VALOR,2)),0)+ISNULL(SUM(VSub),0),
			@ValorBruto = SUM(ISNULL(PCOUNIT,0)*ISNULL(QTD,0))		
			FROM ITENSDOCUMENTO WHERE SEQUENCIAL=@SEQ

			SELECT @VALOR=@VALOR+@ACRESCIMOS-@DESCONTOS
			if @ipimatriz = 'I' begin
				Select @VALOR=@valor-@Acrescimos-@Descontos
			end
			SELECT 
			@BaseICMS=   ISNULL(SUM(BaseICMSITEM),0),
			@BaseIPI=    ISNULL(SUM(BaseIPI),0),
			@BaseISSQN=  ISNULL(SUM(BaseISSQN),0),
			@BaseSubst=	 ISNULL(SUM(BaseSubst),0),
			@ValorSubst= ISNULL(SUM(VSub),0),
			@despesa=	 ISNULL(SUM(despesa),0),
			@VALORIPI=   ISNULL(SUM(VALORIPI),0),
			@VALORISSQN= ISNULL(SUM(VALORISSQN),0),
			@VALORPIS=   ISNULL(SUM(VALORPIS),0),
			@VALORCOFINS=ISNULL(SUM(VALORCOFINS),0),
			@Seguro=     ISNULL(SUM(Seguro),0),
			@FRETE=		 ISNULL(SUM(FRETE),0),		
			@VALORICMS=	 ISNULL(SUM(ValorIcmsItem),0),
			@ACRESCIMOS= ISNULL(SUM(ACRESCIMO),0)+@ACRESCIMOS,	
			@DESCONTOS=  ISNULL(SUM(DESCONTO),0)+@DESCONTOS,
			@DifICMS=  	 ISNULL(SUM(DifICMS),0),
			--@VALOR=		 ISNULL(SUM(VALOR),0)
			
			@TotalOutros = SUM(IsNull(OutrosICMSItem,0)),
			@TotalIsento = SUM(IsNull(IsentoICMSITem,0))
			
			FROM ITENSDOCUMENTO WHERE SEQUENCIAL=@SEQ

			Select @ACRESCIMOS= @ACRESCIMOS + @Seguro + @ValorSubst + @Despesa
			Select @DESCONTOS = @DESCONTOS + @CSLL + @IRPJ 

			--SELECT @TotalOutros = SUM(IsNull(OutrosICMSItem,0)), @TotalIsento = SUM(IsNull(IsentoICMSITem,0)) FROM ITENSDOCUMENTO WHERE SEQUENCIAL = @SEQ
			
			IF @SomarFrete = 'S' BEGIN
				SELECT @SomarFreteVlr = @Frete
			END ELSE BEGIN
				SELECT @SomarFreteVlr = 0
			END
			
			IF  ((SELECT TotalDocItem FROM TiposDoc WHERE Codigo = @TipoDoc)= 'S') or not Exists(Select SeqID From Deleted) BEGIN

				IF @ValorContabVlrLiq = 'S' BEGIN

					UPDATE DOCUMENTOS
					SET BASEICMS = ISNULL(BCIcmsFrete,0) + @BaseICMS, BASEIPI = @BASEIPI, BaseISSQN = @BaseISSQN,
					BCIcmsSubstituicao = @BaseSubst, VIcmsSubstituicao = @ValorSubst, VALORIPI = @VALORIPI,
					VALORISSQN = @VALORISSQN, VALORPIS = @VALORPIS,
					VALORCOFINS = @VALORCOFINS, Seguro = @Seguro, VALORFRETE = @FRETE, Despesa = @Despesa,
					ValorICMS = ISNULL(VIcmsFrete,0) + @VALORICMS,	ACRESCIMOS = @ACRESCIMOS,DESCONTOS=@DESCONTOS,
					VALOR= @VALOR - @ACRESCIMOS - @SomarFreteVlr + @DESCONTOS--+ISNULL(DESPESA,0)
					,DifICMS = @DifICMS,	
					VALORCONTABIL= @VALOR,--+ISNULL(DESPESA,0), 
					VALORTOTAL = @VALOR,--+ISNULL(DESPESA,0), 	
					OutrosICMS = @TotalOutros, IsentoICMS = @TotalIsento,
					CFOP = @CFOPITEM
					WHERE SEQUENCIAL=@SEQ	
					
				END ELSE BEGIN
				
					UPDATE DOCUMENTOS
					SET BASEICMS = ISNULL(BCIcmsFrete,0) + @BaseICMS, BASEIPI = @BASEIPI, BaseISSQN = @BaseISSQN,
					BCIcmsSubstituicao = @BaseSubst, VIcmsSubstituicao = @ValorSubst, VALORIPI = @VALORIPI,
					VALORISSQN = @VALORISSQN, VALORPIS = @VALORPIS,
					VALORCOFINS = @VALORCOFINS, Seguro = @Seguro, VALORFRETE = @FRETE, Despesa = @Despesa,
					ValorICMS = ISNULL(VIcmsFrete,0) + @VALORICMS,	ACRESCIMOS = @ACRESCIMOS,DESCONTOS=@DESCONTOS,
					VALOR= @VALOR - @ACRESCIMOS - @SomarFreteVlr + @DESCONTOS,
					DifICMS = @DifICMS,					
					VALORTOTAL = @VALOR,
					OutrosICMS = @TotalOutros, IsentoICMS = @TotalIsento,
					CFOP = @CFOPITEM
					WHERE SEQUENCIAL=@SEQ	
								
				END
			END ELSE BEGIN
			
				UPDATE DOCUMENTOS
				SET VALOR = @ValorBruto,
					CFOP = @CFOPITEM	 
				WHERE SEQUENCIAL=@SEQ
				
			END
		END
	END
END
GO