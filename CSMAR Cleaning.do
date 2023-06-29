* =============================================================
/* Author Information */

* Name:		Shutter Zor（左祥太）
* Email:	Shutter_Z@outlook.com
* Affiliation:	School of Management, Xiamen University
* Date:		2023/5/13
* Version:	V1.0

* =============================================================



/* 常用控制变量数据清洗教程（ControlVarsDetail.dta）*/ 
/* 说明：本次样本为所有上市公司2009-2022（含2009与2022）的数据 */



********************************************************************************
*- 清洗上市公司基本信息数据
/* 包含变量：STKCD STKNM YEAR INDCD INDNM PROVCD PROVNM CITYCD CITYNM MARKET STATE AGE */

import excel using "DataA-Original/STK_LISTEDCOINFOANL.xlsx", first clear
labone, nrow(1 2) concat("_")
drop in 1/2
	
	*- 生成变量 - 观测年份
	gen YEAR = substr(EndDate,1,4)
	destring YEAR, replace
	
	*- 生成变量 - 成立年份至观测年份的 AGE1
	gen EstablishYear = substr(EstablishDate,1,4)
	destring EstablishYear, replace
	gen AGE1 = YEAR - EstablishYear
	
	*- 生成变量 - 上市年份至观测年份的 AGE2
	gen ListingYear = substr(LISTINGDATE,1,4)
	destring ListingYear, replace
	gen AGE2 = YEAR - ListingYear
	drop if AGE2 < 0		// 去掉部分不合理的观测样本
	
	*- 生成变量 - 股票市场板块 MARKET
	gen MARKET = "深证主板A股" if substr(Symbol,1,2) == "00"
	replace MARKET = "深证创业板" if substr(Symbol,1,2) == "30"
	replace MARKET = "深证B股" if substr(Symbol,1,2) == "20"
	replace MARKET = "上证主板A股" if substr(Symbol,1,2) == "60"
	replace MARKET = "上证科创板" if substr(Symbol,1,2) == "68"
	replace MARKET = "上证B股" if substr(Symbol,1,2) == "90"
	replace MARKET = "北证A股" if substr(Symbol,1,2) == "43" | substr(Symbol,1,2) == "83" | substr(Symbol,1,2) == "87"
	
	*- 重命名变量
	rename (Symbol ShortName IndustryName IndustryCode PROVINCECODE PROVINCE CITYCODE CITY LISTINGSTATE) (STKCD STKNM INDNM INDCD PROVCD PROVNM CITYCD CITYNM STATE)
	
	*- 保留有效变量
	keep STKCD STKNM YEAR INDCD INDNM PROVCD PROVNM CITYCD CITYNM MARKET STATE AGE1 AGE2 
	
	*- 补充变量标签
	label var YEAR		"观测年份"
	label var MARKET	"股票市场板块"
	label var AGE1		"从成立年份到观测年份的年龄"
	label var AGE2		"从上市年份到观测年份的年龄"
	
	*- 排序与保存数据
	order STKCD STKNM YEAR INDCD INDNM PROVCD PROVNM CITYCD CITYNM MARKET STATE AGE1 AGE2 
	label data "基本信息相关变量11+年龄 - From Shutter Zor"
	save "DataB-Hub/Data1.dta", replace

/* 本部分生成的 Data1 用于后续合并 */
/* STKCD STKNM YEAR INDCD INDNM PROVCD PROVNM CITYCD CITYNM MARKET STATE AGE */
********************************************************************************



********************************************************************************
*- 清洗财务报表相关数据
/* 包含变量：CFO GROWTH LEV MFEE OCCUPY ROA ROE SIZE TAT */
	
	*- 资产负债表
	import excel using "DataA-Original/FS_Combas.xlsx", first clear
	labone, nrow(1 2) concat("_")
	drop in 1/2
		
		*- 仅保留合并报表数据
		keep if Typrep == "A"		// A为合并报表，B为母公司报表
		
		*- 仅保留年报数据
		keep if substr(Accper,6,2) == "12"			// 12月的年报
		
		*- 重命名变量
		rename (Stkcd ShortName A001121000 A001000000 A002000000 A003000000) (STKCD STKNM 其他应收款 总资产 总负债 所有者权益)
		
		*- 生成变量 - 观测年份
		gen YEAR = real(substr(Accper,1,4))
		
		*- 生成变量 - 资产负债率 LEV
		destring 总负债 总资产, replace			// 转为数值变量，方便计算
		gen LEV = 总负债 / 总资产

		*- 生成变量 - 大股东资金占用 OCCUPY
		destring 其他应收款, replace
		gen OCCUPY = 其他应收款 / 总资产

		*- 生成变量 - 公司规模 SIZE
		gen SIZE = ln(总资产)
		
		*- 保留有效变量
		keep STKCD STKNM 总资产 所有者权益 YEAR LEV OCCUPY SIZE
		
		*- 补充变量标签
		label var YEAR		"观测年份"
		label var LEV		"资产负债率"
		label var OCCUPY	"大股东资金占用"
		label var SIZE		"公司规模"
		
		*- 保存数据
		label data "资产负债表数据 - From Shutter Zor"
		save "DataB-Hub/Data2.dta", replace
		
	*- 利润表
	import excel using "DataA-Original/FS_Comins.xlsx", first clear
	labone, nrow(1 2) concat("_")
	drop in 1/2	
	
		*- 仅保留合并报表数据
		keep if Typrep == "A"		// A为合并报表，B为母公司报表
		
		*- 仅保留年报数据
		keep if substr(Accper,6,2) == "12"			// 12月的年报
		
		*- 重命名变量
		rename (Stkcd ShortName B001101000 B001210000 B002000000) (STKCD STKNM 营业收入 管理费用 净利润)	
	
		*- 生成变量 - 观测年份
		gen YEAR = real(substr(Accper,1,4))	
		
		*- 生成变量 - 营业收入增长率 GROWTH
		destring 营业收入, replace
		egen STKID = group(STKCD)
		xtset STKID YEAR
		bys STKID: gen GROWTH = (营业收入 - L.营业收入) / L.营业收入
		
		*- 生成变量 - 管理层费用率 MFEE
		destring 管理费用, replace
		gen MFEE = 管理费用 / 营业收入
		
		*- 保留有效变量
		keep STKCD STKNM YEAR 营业收入 净利润 GROWTH MFEE
		
		*- 补充变量标签
		label var YEAR		"观测年份"
		label var GROWTH	"营业收入增长率"
		label var MFEE		"管理层费用率"

		*- 保存数据
		label data "利润表数据 - From Shutter Zor"
		save "DataB-Hub/Data3.dta", replace		
		
	*- 现金流量表 - 直接法
	import excel using "DataA-Original/FS_Comscfd.xlsx", first clear
	labone, nrow(1 2) concat("_")
	drop in 1/2	
	
		*- 仅保留合并报表数据
		keep if Typrep == "A"		// A为合并报表，B为母公司报表
		
		*- 仅保留年报数据
		keep if substr(Accper,6,2) == "12"			// 12月的年报	
	
		*- 重命名变量
		rename (Stkcd ShortName C001000000) (STKCD STKNM 经营活动产生的现金流净额直接法)
		
		*- 生成变量 - 观测年份
		gen YEAR = real(substr(Accper,1,4))
		
		*- 保留有效变量
		keep STKCD STKNM YEAR 经营活动产生的现金流净额直接法
		
		*- 补充变量标签 
		label var YEAR		"观测年份"
		
		*- 保存数据
		label data "现金流量表数据直接法 - From Shutter Zor"
		save "DataB-Hub/Data4.dta", replace			
		
	*- 现金流量表 - 间接法
	import excel using "DataA-Original/FS_Comscfi.xlsx", first clear
	labone, nrow(1 2) concat("_")
	drop in 1/2	
	
		*- 仅保留合并报表数据
		keep if Typrep == "A"		// A为合并报表，B为母公司报表
		
		*- 仅保留年报数据
		keep if substr(Accper,6,2) == "12"			// 12月的年报	
	
		*- 重命名变量
		rename (Stkcd ShortName D000100000) (STKCD STKNM 经营活动产生的现金流净额间接法)
		
		*- 生成变量 - 观测年份
		gen YEAR = real(substr(Accper,1,4))
		
		*- 保留有效变量
		keep STKCD STKNM YEAR 经营活动产生的现金流净额间接法
		
		*- 补充变量标签 
		label var YEAR		"观测年份"
		
		*- 保存数据
		label data "现金流量表数据间接法 - From Shutter Zor"
		save "DataB-Hub/Data5.dta", replace		
		
	*- 合并资产负债表、利润表、现金流量表数据，并计算相关变量
	use "DataB-Hub/Data2.dta", clear
	
		*- 合并利润表
		merge 1:1 STKCD YEAR using "DataB-Hub/Data3.dta"
		keep if _merge == 3			// 仅保留合并上的结果
		drop _merge
	
		*- 合并现金流量表直接法
		merge 1:1 STKCD YEAR using "DataB-Hub/Data4.dta"
		keep if _merge == 3			// 仅保留合并上的结果
		drop _merge
		
		*- 合并现金流量表间接法
		merge 1:1 STKCD YEAR using "DataB-Hub/Data5.dta"
		keep if _merge == 3			// 仅保留合并上的结果
		drop _merge		
	
		*- 生成变量 - 现金流状况 CFO
		destring 经营活动产生的现金流净额直接法 经营活动产生的现金流净额间接法, replace
		gen CFO1 = 经营活动产生的现金流净额直接法 / 总资产
		gen CFO2 = 经营活动产生的现金流净额间接法 / 总资产
	
		*- 生成变量 - 总资产收益率 ROA
		destring 净利润, replace
		gen ROA = 净利润 / 总资产
		
		*- 生成变量 - 净资产收益率 ROE
		destring 所有者权益, replace
		gen ROE = 净利润 / 所有者权益
		
		*- 生成变量 - 总资产周转率 TAT
		gen TAT = 营业收入 / 总资产
		
		*- 保留有效变量
		keep STKCD STKNM YEAR CFO1 CFO2 GROWTH LEV MFEE OCCUPY ROA ROE SIZE TAT
		
		*- 补充变量标签
		label var CFO1		"现金流状况-直接法"
		label var CFO2		"现金流状况-间接法"
		label var ROA		"总资产收益率"
		label var ROE		"净资产收益率"
		label var TAT		"总资产周转率"
		
		*- 排序与保存数据
		order STKCD STKNM YEAR CFO1 CFO2 GROWTH LEV MFEE OCCUPY ROA ROE SIZE TAT
		label data "财务报表相关变量9类10个 - From Shutter Zor"
		save "DataB-Hub/Data6.dta", replace	

/* 本部分生成的 Data6 用于后续合并 */
/* CFO GROWTH LEV MFEE OCCUPY ROA ROE SIZE TAT */
********************************************************************************



********************************************************************************
*- 清洗治理结构相关数据
/* 包含变量：BALANCE BOARD INDBOARD MHOLD TOP1 DUAL */
	
	*- 股东股本相关数据
	/* 包含变量：BALANCE TOP1 */
	
		*- 股东股本相关数据 - 1
		import excel using "DataA-Original/CG_Sharehold.xlsx", first clear
		labone, nrow(1 2) concat("_")
		drop in 1/2
	
			*- 仅保留年报数据
			keep if substr(Reptdt,6,2) == "12"
			
			*- 重命名变量
			rename Stkcd STKCD
			
			*- 生成变量 - 观测年份
			gen YEAR = real(substr(Reptdt,1,4))
			
			*- 生成变量 - 第一大股东持股数量 TOP1
			destring S0301b, replace
			bys STKCD YEAR: egen TOP1 = max(S0301b)
			
			*- 生成变量 - 股权制衡度 BALANCE
			bys STKCD YEAR: egen TOP2_5 = sum(S0301b) if S0501b=="2" | S0501b=="3" | S0501b=="4" | S0501b=="5"			// 生成第二到第五大股东持股比例之和
			gen BALANCE = TOP2_5 / TOP1
			
			*- 保留有效样本
			destring S0501b, replace
			drop if S0501b > 5
			drop if TOP2_5 == .
			duplicates drop STKCD YEAR, force
			
			*- 保留有效变量
			keep STKCD YEAR BALANCE TOP1
			
			*- 补充变量标签
			label var YEAR		"观测年份"
			label var TOP1		"第一大股东持股数量"
			label var BALANCE	"股权制衡度"		
			
			*- 排序与保存数据
			order STKCD YEAR BALANCE TOP1
			label data "股东股本相关数据-1 - From Shutter Zor"
			save "DataB-Hub/Data7-1.dta", replace	
		
		*- 股东股本相关数据 - 2
		import excel using "DataA-Original/CG_Sharehold1.xlsx", first clear
		labone, nrow(1 2) concat("_")
		drop in 1/2
	
			*- 仅保留年报数据
			keep if substr(Reptdt,6,2) == "12"
			
			*- 重命名变量
			rename Stkcd STKCD
			
			*- 生成变量 - 观测年份
			gen YEAR = real(substr(Reptdt,1,4))
			
			*- 生成变量 - 第一大股东持股数量 TOP1
			destring S0301b, replace
			bys STKCD YEAR: egen TOP1 = max(S0301b)
			
			*- 生成变量 - 股权制衡度 BALANCE
			bys STKCD YEAR: egen TOP2_5 = sum(S0301b) if S0501b=="2" | S0501b=="3" | S0501b=="4" | S0501b=="5"			// 生成第二到第五大股东持股比例之和
			gen BALANCE = TOP2_5 / TOP1
			
			*- 保留有效样本
			destring S0501b, replace
			drop if S0501b > 5
			drop if TOP2_5 == .
			duplicates drop STKCD YEAR, force
			
			*- 保留有效变量
			keep STKCD YEAR BALANCE TOP1
			
			*- 补充变量标签
			label var YEAR		"观测年份"
			label var TOP1		"第一大股东持股数量"
			label var BALANCE	"股权制衡度"		
			
			*- 排序与保存数据
			order STKCD YEAR BALANCE TOP1
			label data "股东股本相关数据-2 - From Shutter Zor"
			save "DataB-Hub/Data7-2.dta", replace			
		
		*- 合并股东股本相关数据
		use "DataB-Hub/Data7-1.dta", clear
		append using "DataB-Hub/Data7-2.dta"
		label data "股东股本相关数据 - From Shutter Zor"
		save "DataB-Hub/Data7.dta", replace	
		erase "DataB-Hub/Data7-1.dta"
		erase "DataB-Hub/Data7-2.dta"
		
	*- 高管动态相关数据
	/* 包含变量：BOARD INDBOARD MHOLD */	
	
		*- 高管动态数据
		import excel using "DataA-Original/CG_ManagerShareSalary.xlsx", first clear
		labone, nrow(1 2) concat("_")
		drop in 1/2		
		
			*- 仅保留年末在职人员样本
			keep if StatisticalCaliber == "1"
			
			*- 重命名变量
			rename Symbol STKCD
			
			*- 生成变量 - 观测年份 YEAR
			gen YEAR = real(substr(Enddate,1,4))
			
			*- 生成变量 - 董事规模 BOARD
			destring DirectorNumber, replace
			gen BOARD = ln(DirectorNumber) 
			
			*- 生成变量 - 独立董事占比 INDBOARD
			destring IndependentDirectorNumber, replace
			gen INDBOARD = IndependentDirectorNumber / DirectorNumber
			
			*- 保留有效变量
			keep STKCD YEAR BOARD INDBOARD
			
			*- 补充变量标签
			label var YEAR		"观测年份"
			label var BOARD		"董事规模"
			label var INDBOARD	"独立董事占比"

			*- 保存数据
			label data "高管动态相关数据-1 - From Shutter Zor"
			save "DataB-Hub/Data8-1.dta", replace
		
		*- 股本结构文件
		import excel using "DataA-Original/CG_Capchg.xlsx", first clear
		labone, nrow(1 2) concat("_")
		drop in 1/2		
			
			*- 重命名变量
			rename Stkcd STKCD
	
			*- 生成变量 - 观测年份 YEAR
			gen YEAR = real(substr(Reptdt,1,4))
			
			*- 补充变量标签
			label var YEAR		"观测年份"			
			
			*- 保留有效变量
			keep STKCD YEAR Nshrttl
			
			*- 保存数据
			label data "高管动态相关数据-2 - From Shutter Zor"
			save "DataB-Hub/Data8-2.dta", replace			
	
		*- 合并高管动态与股本结构，主要是计算MHOLD
		use "DataB-Hub/Data8-1.dta", clear
		merge 1:1 STKCD YEAR using "DataB-Hub/Data8-2.dta"
		keep if _merge == 3
		drop _merge
		
			*- 生成变量 - 管理层持股比例 MHOLD
			destring Nshrttl Holdshares, replace
			gen MHOLD = Holdshares / Nshrttl
			
			*- 保留有效变量
			keep STKCD YEAR BOARD INDBOARD MHOLD
			
			*- 补充变量标签
			label var MHOLD		"管理层持股比例"
			
			*- 排序与保存数据
			order STKCD YEAR BOARD INDBOARD MHOLD
			label data "高管动态与股本结构相关数据 - From Shutter Zor"
			save "DataB-Hub/Data8.dta", replace	
			erase "DataB-Hub/Data8-1.dta"
			erase "DataB-Hub/Data8-2.dta"
	
	*- 高管人数、持股相关数据
	/* 包含变量：DUAL */	
	import excel using "DataA-Original/CG_Ybasic.xlsx", first clear
	labone, nrow(1 2) concat("_")
	drop in 1/2
		
		*- 重命名变量
		rename Stkcd STKCD 
		
		*- 生成变量 - 观测年份 YEAR
		gen YEAR = real(substr(Reptdt,1,4))
		
		*- 生成变量 - 两职合一 DUAL
		destring Y1001b, replace
		rename Y1001b DUAL
		replace DUAL = 0 if DUAL == 2
	
		*- 保留有效变量
		keep STKCD YEAR DUAL
		
		*- 补充变量标签
		label var YEAR		"观测年份"
		label var DUAL		"两职合一"
	
		*- 保存数据
		label data "高管人数、持股相关数据 - From Shutter Zor"
		save "DataB-Hub/Data9.dta", replace	
	
	*- 合并治理结构相关数据
	use "DataB-Hub/Data7.dta", clear
	merge 1:1 STKCD YEAR using "DataB-Hub/Data8.dta"
	keep if _merge == 3
	drop _merge
	merge 1:1 STKCD YEAR using "DataB-Hub/Data9.dta"
	keep if _merge == 3
	drop _merge	
	
		*- 排序与保存数据
		order STKCD YEAR BALANCE BOARD INDBOARD MHOLD TOP1 DUAL
		label data "治理结构相关变量6个 - From Shutter Zor"
		save "DataB-Hub/Data10.dta", replace	

/* 本部分生成的 Data10 用于后续合并 */
/* BALANCE BOARD INDBOARD MHOLD TOP1 DUAL */
********************************************************************************	
	
	
	
********************************************************************************
*- 清洗财务指标分析相关数据
/* 包含变量：BM TobinQ */

import excel using "DataA-Original/FI_T10.xlsx", first clear
labone, nrow(1 2) concat("_")
drop in 1/2
	
	*- 仅保留年报数据
	keep if substr(Accper,6,2) == "12"

	*- 重命名变量
	rename (Stkcd ShortName F100901A F100902A F100903A F100904A F101001A F101002A) (STKCD STKNM TobinQ1 TobinQ2 TobinQ3 TobinQ4 BM1 BM2)

	*- 生成变量 - 观测年份 YEAR
	gen YEAR = real(substr(Accper,1,4))

	*- 生成变量 - 账面市值比 BM 与 托宾Q值 TobinQ 
	destring BM* TobinQ*, replace
	
	*- 保留有效变量
	keep STKCD YEAR BM* TobinQ*

	*- 补充变量标签
	label var YEAR		"观测年份"

	*- 保存数据
	label data "财务指标分析相关变量2个"
	save "DataB-Hub/Data11.dta", replace	

/* 本部分生成的 Data11 用于后续合并 */
/* BM TobinQ */
********************************************************************************
	
	
	
********************************************************************************
*- 清洗机构投资者相关数据
/* 包含变量：INSTITUTION */

import excel using "DataA-Original/INI_HolderSystematics.xlsx", first clear
labone, nrow(1 2) concat("_")
drop in 1/2
	
	*- 仅保留年报数据
	keep if substr(EndDate,6,2) == "12"

	*- 重命名变量
	rename (Symbol InsInvestorProp) (STKCD INSTITUTION)

	*- 生成变量 - 观测年份 YEAR
	gen YEAR = real(substr(EndDate,1,4))

	*- 生成变量 - 机构投资者比例 INSTITUTION
	destring INSTITUTION, replace
	
	*- 保留有效变量
	keep STKCD YEAR INSTITUTION

	*- 补充变量标签
	label var YEAR		"观测年份"

	*- 保存数据
	label data "机构投资者相关变量1个"
	save "DataB-Hub/Data12.dta", replace	

/* 本部分生成的 Data12 用于后续合并 */
/* INSTITUTION */
********************************************************************************
	
	
	
********************************************************************************
*- 清洗分析师预测相关数据
/* 包含变量：AUDIT */

import excel using "DataA-Original/AF_CFEATUREPROFILE.xlsx", first clear
labone, nrow(1 2) concat("_")
drop in 1/2
	
	*- 仅保留年报数据
	keep if substr(Accper,6,2) == "12"

	*- 重命名变量
	rename (Stknmec Stkcd) (STKNM STKCD)

	*- 生成变量 - 观测年份 YEAR
	gen YEAR = real(substr(Accper,1,4))

	*- 生成变量 - 是否由四大会计师事务所审计 AUDIT
	gen AUDIT = 1 if Big4 == "Y"
	replace AUDIT = 0 if Big4 == "N"
	
	*- 保留有效变量
	keep STKCD YEAR AUDIT

	*- 补充变量标签
	label var YEAR		"观测年份"
	label var AUDIT		"是否由四大会计师事务所审计"

	*- 保存数据
	label data "分析师预测相关变量1个"
	save "DataB-Hub/Data13.dta", replace	

/* 本部分生成的 Data13 用于后续合并 */
/* AUDIT */
********************************************************************************
	
	
	
********************************************************************************
*- 清洗财务报告审计意见相关数据
/* 包含变量：OPINION */

import excel using "DataA-Original/FIN_Audit.xlsx", first clear
labone, nrow(1 2) concat("_")
drop in 1/2
	
	*- 仅保留年报数据
	keep if substr(Accper,6,2) == "12"

	*- 重命名变量
	rename (Stkcd Stknme) (STKCD STKNM)

	*- 生成变量 - 观测年份 YEAR
	gen YEAR = real(substr(Accper,1,4))

	*- 生成变量 - 是否由四大会计师事务所审计 AUDIT
	gen OPINION = 1 if Audittyp == "标准无保留意见"
	replace OPINION = 0 if Audittyp != "标准无保留意见"
	
	*- 保留有效变量
	keep STKCD YEAR OPINION

	*- 补充变量标签
	label var YEAR		"观测年份"
	label var OPINION	"是否标准无保留意见"

	*- 保存数据
	label data "财务报告审计意见相关变量1个"
	save "DataB-Hub/Data14.dta", replace	

/* 本部分生成的 Data14 用于后续合并 */
/* OPINION */
********************************************************************************
	
	
	
********************************************************************************
*- 清洗股权性质相关数据
/* 包含变量：SOE */

import excel using "DataA-Original/EN_EquityNatureAll.xlsx", first clear
labone, nrow(1 2) concat("_")
drop in 1/2
	
	*- 仅保留年报数据
	keep if substr(EndDate,6,2) == "12"

	*- 重命名变量
	rename (Symbol ShortName) (STKCD STKNM)

	*- 生成变量 - 观测年份 YEAR
	gen YEAR = real(substr(EndDate,1,4))

	*- 生成变量 - 是否为国企 SOE
	gen SOE = 1 if EquityNature == "国企"
	replace SOE = 0 if EquityNature != "国企"
	
	*- 保留有效变量
	keep STKCD YEAR SOE

	*- 补充变量标签
	label var YEAR		"观测年份"
	label var SOE		"是否为国企"

	*- 保存数据
	label data "股权性质相关变量1个"
	save "DataB-Hub/Data15.dta", replace	

/* 本部分生成的 Data15 用于后续合并 */
/* SOE */
********************************************************************************





********************************************************************************
/* 至此完成了所有数据变量的计算，接下来需要将所有内容完全合并 */
/* 文件位置：DataB-Hub
Data1.dta:		STKCD STKNM YEAR INDCD INDNM PROVCD PROVNM CITYCD CITYNM MARKET STATE AGE
Data6.dta:		CFO GROWTH LEV MFEE OCCUPY ROA ROE SIZE TAT
Data10.dta:		BALANCE BOARD INDBOARD MHOLD TOP1 DUAL
Data11.dta:		BM TobinQ
Data12.dta:		INSTITUTION
Data13.dta:		AUDIT
Data14.dta:		OPINION
Data15.dta:		SOE
总计：			33 种变量，其中 AGE、BM、CFO、TobinQ 含有多类
*/

*- 最终合并
use "DataB-Hub/Data1.dta", clear
merge 1:1 STKCD YEAR using "DataB-Hub/Data6.dta"
keep if _merge == 3
drop _merge
merge 1:1 STKCD YEAR using "DataB-Hub/Data10.dta"
keep if _merge == 3
drop _merge
merge 1:1 STKCD YEAR using "DataB-Hub/Data11.dta"
keep if _merge == 3
drop _merge
merge 1:1 STKCD YEAR using "DataB-Hub/Data12.dta"
keep if _merge == 3
drop _merge
merge 1:1 STKCD YEAR using "DataB-Hub/Data13.dta"
keep if _merge == 3
drop _merge
merge 1:1 STKCD YEAR using "DataB-Hub/Data14.dta"
keep if _merge == 3
drop _merge
merge 1:1 STKCD YEAR using "DataB-Hub/Data15.dta"
keep if _merge == 3
drop _merge

*- 排序与保存数据
order STKCD STKNM YEAR INDCD INDNM PROVCD PROVNM CITYCD CITYNM MARKET STATE AGE1 AGE2 BALANCE BM1 BM2 BOARD CFO1 CFO2 GROWTH INDBOARD INSTITUTION LEV MFEE MHOLD OCCUPY ROA ROE SIZE TAT TobinQ1 TobinQ2 TobinQ3 TobinQ4 TOP1 AUDIT DUAL OPINION SOE
	
label data "Datasets of commonly used control variables. By Shutter Zor (Shutter_Z@outlook)"
save ControlVarsDetail.dta, replace	
	
	


	
