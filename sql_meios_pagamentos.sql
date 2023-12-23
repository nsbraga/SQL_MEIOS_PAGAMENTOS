/* Criacao da estrutura da tabela  base_nome_filial */ 

CREATE TABLE `base_nome_filial` (
  `filial` text,
  `nome_filial` text
) ENGINE=InnoDB AUTO_INCREMENT=13556 DEFAULT CHARSET=utf8mb3;

/* Carga na tabela  base_nome_filial */ 

LOAD DATA INFILE 'c:/ProgramData/MySQL/MySQL Server 8.0/Uploads/base_nome_filial.csv' INTO TABLE  north.base_nome_filial
CHARACTER SET 'utf8'
FIELDS TERMINATED BY ';' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;


/* Criacao da estrutura da tabela  vendas_receitas_trim */ 
 
CREATE TABLE `vendas_receitas_trim` (`data` text,   `cnpj_filial` text,   `cnpj_cpf_ec` text,   `nome_ec` text,   `mcc` text,
  `mcc_categoria` text,   `qtdepos` text,   `tpv` text,  `receita_ad` text,    `receita_sub` text,   `receita_deb` text,  `receita_cred_vista` text,
  `receita_cred_2_6` text,   `receita_cred_7_12` text   ) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8mb3;

LOAD DATA INFILE 'c:/ProgramData/MySQL/MySQL Server 8.0/Uploads/tpv_receita_trim.csv' INTO TABLE  north.vendas_receitas_trim
CHARACTER SET 'utf8'
FIELDS TERMINATED BY ';' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;



/*  Somar os valores quantitativos da base e calcular o % do tpv por tipo de pagamento (débito / tpv , credito / tpv, etc), 
e o take rate (receita / tpv)  */ 


select  
count(qtdepos) as total_pos, round(sum(tpv), 2) as tpv, round(avg(tpv), 2) as media_tpv,  round(sum(receita_ad),2 ) as receita_adq, 
round(sum(receita_ad) /  sum(tpv) * 100, 2) as take_rate_adq, round(sum(receita_sub), 2) as receita_sub, 
round(sum(receita_sub) /  sum(tpv) * 100, 2) as take_rate_sub, round(sum(receita_deb), 2) as receita_deb, 
round(sum(receita_deb) / sum(receita_sub), 3) * 100 as '% debito',  round(sum(receita_deb) /  sum(tpv) * 100, 2) as take_rate_subdebito, 
round(sum(receita_cred_vista), 2) as receita_cred_vista, round(sum(receita_cred_vista) / sum(receita_sub), 3) * 100 as '% cred_vista', 
round(sum(receita_cred_vista) /  sum(tpv) * 100, 2) as take_rate_subcredito, round(sum(receita_cred_2_6)) as receita_cred_2_6, 
round(sum(receita_cred_2_6) / sum(receita_sub), 3) * 100 as '% cred_2_6',  round(sum(receita_cred_2_6) /  sum(tpv) * 100, 2) as take_rate_subcred_2_6,
round(sum(receita_cred_7_12), 2) as receita_cred_7_12, round(sum(receita_cred_7_12) / sum(receita_sub), 3) * 100 as '% cred_7_12', 
round(sum(receita_cred_7_12) /  sum(tpv) * 100, 2) as take_rate_subcred_7_12 
from  north.vendas_receitas_trim;


/* Ranking das filiais com maior quantidade de estabelecimentos comercial transacionando no trimestre, 
quantidade de POS e o ticket médio por EC e por  POS */ 

select    b.nome_filial,  round(sum(a.tpv), 2) as tpv,  count(distinct(a.cnpj_cpf_ec)) as qtde_ec,  count(a.qtdepos) as qtde_pos ,
round(sum(a.tpv)  / count(distinct(a.cnpj_cpf_ec)), 2) as ticket_medio_ec,
round(sum(a.tpv)  / count(a.qtdepos), 2) as ticket_medio_pos
from   north.vendas_receitas_trim a
join north.base_nome_filial b 
on a.cnpj_filial = b.filial
group by  b.nome_filial 
order by  qtde_ec desc; 



/* TOP 5 dos ECs com maior tpv por ano e mes e suas respectivas receitas */ 
WITH ranked_data AS (
    SELECT
        a.data,
        b.nome_filial,
		sum(a.tpv) AS tpv,
        sum(receita_sub) as receita_sub, 
        ROW_NUMBER() OVER (PARTITION BY a.data ORDER BY sum(a.tpv) DESC) AS row_num
    FROM  north.vendas_receitas_trim a
		  join north.base_nome_filial b 
		  on a.cnpj_filial = b.filial
    GROUP BY a.data, b.nome_filial
    ORDER BY a.data, sum(a.tpv) DESC
)
SELECT data, nome_filial, round(tpv, 2) as tpv, round(receita_sub, 2) as receita_sub
FROM ranked_data
WHERE row_num <= 5;


drop temporary table  if exists  dbfit02.tmptrim ;

/* TOP 10 dos ECs com maior queda de receita comparando  Novembro com Outubro, e Dezembro com Novembro  */ 

 create temporary table dbfit02.tmptrim 
select a.cnpj_cpf_ec, 
round(sum( if(a.data='2022-10',a.receita_sub,0) ), 2) as 'receita_out_22', 
round(sum( if(a.data='2022-11',a.receita_sub,0) ), 2) as 'receita_nov_22',
round(sum( if(a.data='2022-12',a.receita_sub,0) ), 2) as 'receita_dez_22'
from   north.vendas_receitas_trim a
group by a.cnpj_cpf_ec;

select *, round(((receita_nov_22 / receita_out_22) - 1) * 100, 0) as perc_nov  from dbfit02.tmptrim 
where receita_out_22 > 0 and receita_nov_22 > 0 and  receita_dez_22 > 0 
order by perc_nov
limit 10; 



select *, round(((receita_dez_22 / receita_nov_22) - 1) * 100, 0) as perc_dez  from dbfit02.tmptrim 
where receita_out_22 > 0 and receita_nov_22 > 0 and  receita_dez_22 > 0 
order by perc_dez
limit 10; 


 /* TOP 10 dos ECs com maior aumento de receita comparando Novembro x Outubro   */ 
 

select cnpj_cpf_ec, receita_out_22, receita_nov_22, round(((receita_nov_22 / receita_out_22) - 1) * 100, 0) as perc_nov  
from dbfit02.tmptrim  
where receita_out_22 > 0 and receita_nov_22 > 0 and  receita_dez_22 > 0 
and (((receita_nov_22 / receita_out_22) - 1) * 100) > 0
order by perc_nov desc
limit 10; 



 /* TOP 10 dos ECs com maior aumento de receita se comparado Dezembro x Novembro   */ 

select  cnpj_cpf_ec, receita_nov_22, receita_dez_22,  round(((receita_dez_22 / receita_nov_22) - 1) * 100, 0) as perc_dez  from dbfit02.tmptrim 
where receita_out_22 > 0 and receita_nov_22 > 0 and  receita_dez_22 > 0 
and (((receita_dez_22 / receita_nov_22) - 1) * 100) > 0
order by perc_dez desc
limit 10; 


/* TOP 10 com maior receita agrupado por segmento (mcc) */ 
 
 
 /* Obter o TPV total da base para cálculo do percentual por MCC
 
 */ 
 
 select sum(tpv)  into @tpv from   north.vendas_receitas_trim;
 
  /* Obter o a receita total da base para cálculo do percentual por MCC */ 
  
  select sum(receita_sub) into @receita_sub from   north.vendas_receitas_trim;
 
select mcc_categoria, count(*) as qtde_mcc, round(((count(*) / 364) * 100), 2) as perc_mcc, 
round(sum(tpv), 2) as tpv, round((sum(tpv) /  @tpv) *100, 2) as perc_tpv,  
round(sum(receita_sub), 2) as receita_sub, 
round((sum(receita_sub) /  @receita_sub) *100, 2) as perc_receita_sub 
 from   north.vendas_receitas_trim
group by mcc_categoria
order by receita_sub desc


