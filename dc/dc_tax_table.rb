module DcTaxTable

  def self.parse_table(table)
    res = []
    table.each_line do |line|
      res.push(line.chomp.split(/\s+/).map(&:to_i))
    end
    return res
  end

  def compute_tax_table(income)
    TAX_TABLE.each do |row|
      if income >= row[0] && income <= row[1]
        return row[2]
      end
    end
    raise "Income #{income} not found in tax table"
  end

  def compute_tax(income)
    if income <= 100000
      return compute_tax_table(income)
    elsif income < 350000
      return 3500 + (0.085 * (income - 60000)).round
    elsif income < 1000000
      return 28150 + (0.0875 * (income - 350000)).round
    else
      return 85025 + (0.0895 * (income - 1000000)).round
    end
  end

  def exemption_reduction(agi)
    if agi > 275000
      return 1775
    elsif agi <= 150000
      return 0
    else
      reductions = (agi - 150000) / 2500 + (agi % 2500 == 0 ? 0 : 1)
      return (1775 * 0.02 * reductions).round
    end
  end


  TAX_TABLE = parse_table(<<EOF)
0	49	0
50	99	3
100	149	5
150	199	7
200	249	9
250	299	11
300	349	13
350	399	15
400	449	17
450	499	19
500	549	21
550	599	23
600	649	25
650	699	27
700	749	29
750	799	31
800	849	33
850	899	35
900	949	37
950	999	39
1000	1049	41
1050	1099	43
1100	1149	45
1150	1199	47
1200	1249	49
1250	1299	51
1300	1349	53
1350	1399	55
1400	1449	57
1450	1499	59
1500	1549	61
1550	1599	63
1600	1649	65
1650	1699	67
1700	1749	69
1750	1799	71
1800	1849	73
1850	1899	75
1900	1949	77
1950	1999	79
2000	2049	81
2050	2099	83
2100	2149	85
2150	2199	87
2200	2249	89
2250	2299	91
2300	2349	93
2350	2399	95
2400	2449	97
2450	2499	99
2500	2549	101
2550	2599	103
2600	2649	105
2650	2699	107
2700	2749	109
2750	2799	111
2800	2849	113
2850	2899	115
2900	2949	117
2950	2999	119
3000	3049	121
3050	3099	123
3100	3149	125
3150	3199	127
3200	3249	129
3250	3299	131
3300	3349	133
3350	3399	135
3400	3449	137
3450	3499	139
3500	3549	141
3550	3599	143
3600	3649	145
3650	3699	147
3700	3749	149
3750	3799	151
3800	3849	153
3850	3899	155
3900	3949	157
3950	3999	159
4000	4049	161
4050	4099	163
4100	4149	165
4150	4199	167
4200	4249	169
4250	4299	171
4300	4349	173
4350	4399	175
4400	4449	177
4450	4499	179
4500	4549	181
4550	4599	183
4600	4649	185
4650	4699	187
4700	4749	189
4750	4799	191
4800	4849	193
4850	4899	195
4900	4949	197
4950	4999	199
5000	5049	201
5100	5149	205
5150	5199	207
5200	5249	209
5250	5299	211
5300	5349	213
5350	5399	215
5400	5449	217
5450	5499	219
5500	5549	221
5550	5599	223
5600	5649	225
5650	5699	227
5700	5749	229
5750	5799	231
5800	5849	233
5850	5899	235
5900	5949	237
5950	5999	239
6000	6049	241
6050	6099	243
6100	6149	245
6150	6199	247
6200	6249	249
6250	6299	251
6300	6349	253
6350	6399	255
6400	6449	257
6450	6499	259
6500	6549	261
6550	6599	263
6600	6649	265
6650	6699	267
6700	6749	269
6750	6799	271
6800	6849	273
6850	6899	275
6900	6949	277
6950	6999	279
7000	7049	281
7050	7099	283
7100	7149	285
7150	7199	287
7200	7249	289
7250	7299	291
7300	7349	293
7350	7399	295
7400	7449	297
7450	7499	299
7500	7549	301
7600	7649	305
7650	7699	307
7700	7749	309
7750	7799	311
7800	7849	313
7850	7899	315
7900	7949	317
7950	7999	319
8000	8049	321
8050	8099	323
8100	8149	325
8150	8199	327
8200	8249	329
8250	8299	331
8300	8349	333
8350	8399	335
8400	8449	337
8450	8499	339
8500	8549	341
8550	8599	343
8600	8649	345
8650	8699	347
8700	8749	349
8750	8799	351
8800	8849	353
8850	8899	355
8900	8949	357
8950	8999	359
9000	9049	361
9050	9099	363
9100	9149	365
9150	9199	367
9200	9249	369
9250	9299	371
9300	9349	373
9350	9399	375
9400	9449	377
9450	9499	379
9500	9549	381
9550	9599	383
9600	9649	385
9650	9699	387
9700	9749	389
9750	9799	391
9800	9849	393
9850	9899	395
9900	9949	397
9950	9999	399
10000	10049	402
10050	10099	405
10100	10149	408
10150	10199	411
10200	10249	414
10250	10299	417
10300	10349	420
10350	10399	423
10400	10449	426
10450	10499	429
10500	10549	432
10550	10599	435
10600	10649	438
10650	10699	441
10700	10749	444
10750	10799	447
10800	10849	450
10850	10899	453
10900	10949	456
10950	10999	459
11000	11049	462
11050	11099	465
11100	11149	468
11150	11199	471
11200	11249	474
11250	11299	477
11300	11349	480
11350	11399	483
11400	11449	486
11450	11499	489
11500	11549	492
11550	11599	495
11600	11649	498
11650	11699	501
11700	11749	504
11750	11799	507
11800	11849	510
11850	11899	513
11900	11949	516
11950	11999	519
12000	12049	522
12050	12099	525
12100	12149	528
12150	12199	531
12200	12249	534
12250	12299	537
12300	12349	540
12350	12399	543
12400	12449	546
12450	12499	549
12500	12549	552
12550	12599	555
12600	12649	558
12650	12699	561
12700	12749	564
12750	12799	567
12800	12849	570
12850	12899	573
12900	12949	576
12950	12999	579
13000	13049	582
13050	13099	585
13100	13149	588
13150	13199	591
13200	13249	594
13250	13299	597
13300	13349	600
13350	13399	603
13400	13449	606
13450	13499	609
13500	13549	612
13550	13599	615
13600	13649	618
13650	13699	621
13700	13749	624
13750	13799	627
13800	13849	630
13850	13899	633
13900	13949	636
13950	13999	639
14000	14049	642
14050	14099	645
14100	14149	648
14150	14199	651
14200	14249	654
14250	14299	657
14300	14349	660
14350	14399	663
14400	14449	666
14450	14499	669
14500	14549	672
14550	14599	675
14600	14649	678
14650	14699	681
14700	14749	684
14750	14799	687
14800	14849	690
14850	14899	693
14900	14949	696
14950	14999	699
15000	15049	702
15050	15099	705
15100	15149	708
15150	15199	711
15200	15249	714
15250	15299	717
15300	15349	720
15350	15399	723
15400	15449	726
15450	15499	729
15500	15549	732
15550	15599	735
15600	15649	738
15650	15699	741
15700	15749	744
15750	15799	747
15800	15849	750
15850	15899	753
15900	15949	756
15950	15999	759
16000	16049	762
16050	16099	765
16100	16149	768
16150	16199	771
16200	16249	774
16250	16299	777
16300	16349	780
16350	16399	783
16400	16449	786
16450	16499	789
16500	16549	792
16550	16599	795
16600	16649	798
16650	16699	801
16700	16749	804
16750	16799	807
16800	16849	810
16850	16899	813
16900	16949	816
16950	16999	819
17000	17049	822
17050	17099	825
17100	17149	828
17150	17199	831
17200	17249	834
17250	17299	837
17300	17349	840
17350	17399	843
17400	17449	846
17450	17499	849
17500	17549	852
17550	17599	855
17600	17649	858
17650	17699	861
17700	17749	864
17750	17799	867
17800	17849	870
17850	17899	873
17900	17949	876
17950	17999	879
18000	18049	882
18050	18099	885
18100	18149	888
18150	18199	891
18200	18249	894
18250	18299	897
18300	18349	900
18350	18399	903
18400	18449	906
18450	18499	909
18500	18549	912
18550	18599	915
18600	18649	918
18650	18699	921
18700	18749	924
18750	18799	927
18800	18849	930
18850	18899	933
18900	18949	936
18950	18999	939
19000	19049	942
19050	19099	945
19100	19149	948
19150	19199	951
19200	19249	954
19250	19299	957
19300	19349	960
19350	19399	963
19400	19449	966
19450	19499	969
19500	19549	972
19550	19599	975
19600	19649	978
19650	19699	981
19700	19749	984
19750	19799	987
19800	19849	990
19850	19899	993
19900	19949	996
19950	19999	999
20000	20049	1002
20050	20099	1005
20100	20149	1008
20150	20199	1011
20200	20249	1014
20250	20299	1017
20300	20349	1020
20350	20399	1023
20400	20449	1026
20450	20499	1029
20500	20549	1032
20550	20599	1035
20600	20649	1038
20650	20699	1041
20700	20749	1044
20750	20799	1047
20800	20849	1050
20850	20899	1053
20900	20949	1056
20950	20999	1059
21000	21049	1062
21050	21099	1065
21100	21149	1068
21150	21199	1071
21200	21249	1074
21250	21299	1077
21300	21349	1080
21350	21399	1083
21400	21449	1086
21450	21499	1089
21500	21549	1092
21550	21599	1095
21600	21649	1098
21650	21699	1101
21700	21749	1104
21750	21799	1107
21800	21849	1110
21850	21899	1113
21900	21949	1116
21950	21999	1119
22000	22049	1122
22050	22099	1125
22100	22149	1128
22150	22199	1131
22200	22249	1134
22250	22299	1137
22300	22349	1140
22350	22399	1143
22400	22449	1146
22450	22499	1149
22500	22549	1152
22550	22599	1155
22600	22649	1158
22650	22699	1161
22700	22749	1164
22750	22799	1167
22800	22849	1170
22850	22899	1173
22900	22949	1176
22950	22999	1179
23000	23049	1182
23050	23099	1185
23100	23149	1188
23150	23199	1191
23200	23249	1194
23250	23299	1197
23300	23349	1200
23350	23399	1203
23400	23449	1206
23450	23499	1209
23500	23549	1212
23550	23599	1215
23600	23649	1218
23650	23699	1221
23700	23749	1224
23750	23799	1227
23800	23849	1230
23850	23899	1233
23900	23949	1236
23950	23999	1239
24000	24049	1242
24050	24099	1245
24100	24149	1248
24150	24199	1251
24200	24249	1254
24250	24299	1257
24300	24349	1260
24350	24399	1263
24400	24449	1266
24450	24499	1269
24500	24549	1272
24550	24599	1275
24600	24649	1278
24650	24699	1281
24700	24749	1284
24750	24799	1287
24800	24849	1290
24850	24899	1293
24900	24949	1296
24950	24999	1299
25000	25049	1302
25050	25099	1305
25100	25149	1308
25150	25199	1311
25200	25249	1314
25250	25299	1317
25300	25349	1320
25350	25399	1323
25400	25449	1326
25450	25499	1329
25500	25549	1332
25550	25599	1335
25600	25649	1338
25650	25699	1341
25700	25749	1344
25750	25799	1347
25800	25849	1350
25850	25899	1353
25900	25949	1356
25950	25999	1359
26000	26049	1362
26050	26099	1365
26100	26149	1368
26150	26199	1371
26200	26249	1374
26250	26299	1377
26300	26349	1380
26350	26399	1383
26400	26449	1386
26450	26499	1389
26500	26549	1392
26550	26599	1395
26600	26649	1398
26650	26699	1401
26700	26749	1404
26750	26799	1407
26800	26849	1410
26850	26899	1413
26900	26949	1416
26950	26999	1419
27000	27049	1422
27050	27099	1425
27100	27149	1428
27150	27199	1431
27200	27249	1434
27250	27299	1437
27300	27349	1440
27350	27399	1443
27400	27449	1446
27450	27499	1449
27500	27549	1452
27550	27599	1455
27600	27649	1458
27650	27699	1461
27700	27749	1464
27750	27799	1467
27800	27849	1470
27850	27899	1473
27900	27949	1476
27950	27999	1479
28000	28049	1482
28050	28099	1485
28100	28149	1488
28150	28199	1491
28200	28249	1494
28250	28299	1497
28300	28349	1500
28350	28399	1503
28400	28449	1506
28450	28499	1509
28500	28549	1512
28550	28599	1515
28600	28649	1518
28650	28699	1521
28700	28749	1524
28750	28799	1527
28800	28849	1530
28850	28899	1533
28900	28949	1536
28950	28999	1539
29000	29049	1542
29050	29099	1545
29100	29149	1548
29150	29199	1551
29200	29249	1554
29250	29299	1557
29300	29349	1560
29350	29399	1563
29400	29449	1566
29450	29499	1569
29500	29549	1572
29550	29599	1575
29600	29649	1578
29650	29699	1581
29700	29749	1584
29750	29799	1587
29800	29849	1590
29850	29899	1593
29900	29949	1596
29950	29999	1599
30000	30049	1602
30050	30099	1605
30100	30149	1608
30150	30199	1611
30200	30249	1614
30250	30299	1617
30300	30349	1620
30350	30399	1623
30400	30449	1626
30450	30499	1629
30500	30549	1632
30550	30599	1635
30600	30649	1638
30650	30699	1641
30700	30749	1644
30750	30799	1647
30800	30849	1650
30850	30899	1653
30900	30949	1656
30950	30999	1659
31000	31049	1662
31050	31099	1665
31100	31149	1668
31150	31199	1671
31200	31249	1674
31250	31299	1677
31300	31349	1680
31350	31399	1683
31400	31449	1686
31450	31499	1689
31500	31549	1692
31550	31599	1695
31600	31649	1698
31650	31699	1701
31700	31749	1704
31750	31799	1707
31800	31849	1710
31850	31899	1713
31900	31949	1716
31950	31999	1719
32000	32049	1722
32050	32099	1725
32100	32149	1728
32150	32199	1731
32200	32249	1734
32250	32299	1737
32300	32349	1740
32350	32399	1743
32400	32449	1746
32450	32499	1749
32500	32549	1752
32550	32599	1755
32600	32649	1758
32650	32699	1761
32700	32749	1764
32750	32799	1767
32800	32849	1770
32850	32899	1773
32900	32949	1776
32950	32999	1779
33000	33049	1782
33050	33099	1785
33100	33149	1788
33150	33199	1791
33200	33249	1794
33250	33299	1797
33300	33349	1800
33350	33399	1803
33400	33449	1806
33450	33499	1809
33500	33549	1812
33550	33599	1815
33600	33649	1818
33650	33699	1821
33700	33749	1824
33750	33799	1827
33800	33849	1830
33850	33899	1833
33900	33949	1836
33950	33999	1839
34000	34049	1842
34050	34099	1845
34100	34149	1848
34150	34199	1851
34200	34249	1854
34250	34299	1857
34300	34349	1860
34350	34399	1863
34400	34449	1866
34450	34499	1869
34500	34549	1872
34550	34599	1875
34600	34649	1878
34650	34699	1881
34700	34749	1884
34750	34799	1887
34800	34849	1890
34850	34899	1893
34900	34949	1896
34950	34999	1899
35000	35049	1902
35050	35099	1905
35100	35149	1908
35150	35199	1911
35200	35249	1914
35250	35299	1917
35300	35349	1920
35350	35399	1923
35400	35449	1926
35450	35499	1929
35500	35549	1932
35550	35599	1935
35600	35649	1938
35650	35699	1941
35700	35749	1944
35750	35799	1947
35800	35849	1950
35850	35899	1953
35900	35949	1956
35950	35999	1959
36000	36049	1962
36050	36099	1965
36100	36149	1968
36150	36199	1971
36200	36249	1974
36250	36299	1977
36300	36349	1980
36350	36399	1983
36400	36449	1986
36450	36499	1989
36500	36549	1992
36550	36599	1995
36600	36649	1998
36650	36699	2001
36700	36749	2004
36750	36799	2007
36800	36849	2010
36850	36899	2013
36900	36949	2016
36950	36999	2019
37000	37049	2022
37050	37099	2025
37100	37149	2028
37150	37199	2031
37200	37249	2034
37250	37299	2037
37300	37349	2040
37350	37399	2043
37400	37449	2046
37450	37499	2049
37500	37549	2052
37550	37599	2055
37600	37649	2058
37650	37699	2061
37700	37749	2064
37750	37799	2067
37800	37849	2070
37850	37899	2073
37900	37949	2076
37950	37999	2079
38000	38049	2082
38050	38099	2085
38100	38149	2088
38150	38199	2091
38200	38249	2094
38250	38299	2097
38300	38349	2100
38350	38399	2103
38400	38449	2106
38450	38499	2109
38500	38549	2112
38550	38599	2115
38600	38649	2118
38650	38699	2121
38700	38749	2124
38750	38799	2127
38800	38849	2130
38850	38899	2133
38900	38949	2136
38950	38999	2139
39000	39049	2142
39050	39099	2145
39100	39149	2148
39150	39199	2151
39200	39249	2154
39250	39299	2157
39300	39349	2160
39350	39399	2163
39400	39449	2166
39450	39499	2169
39500	39549	2172
39550	39599	2175
39600	39649	2178
39650	39699	2181
39700	39749	2184
39750	39799	2187
39800	39849	2190
39850	39899	2193
39900	39949	2196
39950	39999	2199
40000	40049	2202
40050	40099	2205
40100	40149	2208
40150	40199	2211
40200	40249	2215
40250	40299	2218
40300	40349	2221
40350	40399	2224
40400	40449	2228
40450	40499	2231
40500	40549	2234
40550	40599	2237
40600	40649	2241
40650	40699	2244
40700	40749	2247
40750	40799	2250
40800	40849	2254
40850	40899	2257
40900	40949	2260
40950	40999	2263
41000	41049	2267
41050	41099	2270
41100	41149	2273
41150	41199	2276
41200	41249	2280
41250	41299	2283
41300	41349	2286
41350	41399	2289
41400	41449	2293
41450	41499	2296
41500	41549	2299
41550	41599	2302
41600	41649	2306
41650	41699	2309
41700	41749	2312
41750	41799	2315
41800	41849	2319
41850	41899	2322
41900	41949	2325
41950	41999	2328
42000	42049	2332
42050	42099	2335
42100	42149	2338
42150	42199	2341
42200	42249	2345
42250	42299	2348
42300	42349	2351
42350	42399	2354
42400	42449	2358
42450	42499	2361
42500	42549	2364
42550	42599	2367
42600	42649	2371
42650	42699	2374
42700	42749	2377
42750	42799	2380
42800	42849	2384
42850	42899	2387
42900	42949	2390
42950	42999	2393
43000	43049	2397
43050	43099	2400
43100	43149	2403
43150	43199	2406
43200	43249	2410
43250	43299	2413
43300	43349	2416
43350	43399	2419
43400	43449	2423
43450	43499	2426
43500	43549	2429
43550	43599	2432
43600	43649	2436
43650	43699	2439
43700	43749	2442
43750	43799	2445
43800	43849	2449
43850	43899	2452
43900	43949	2455
43950	43999	2458
44000	44049	2462
44050	44099	2465
44100	44149	2468
44150	44199	2471
44200	44249	2475
44250	44299	2478
44300	44349	2481
44350	44399	2484
44400	44449	2488
44450	44499	2491
44500	44549	2494
44550	44599	2497
44600	44649	2501
44650	44699	2504
44700	44749	2507
44750	44799	2510
44800	44849	2514
44850	44899	2517
44900	44949	2520
44950	44999	2523
45000	45049	2527
45050	45099	2530
45100	45149	2533
45150	45199	2536
45200	45249	2540
45250	45299	2543
45300	45349	2546
45350	45399	2549
45400	45449	2553
45450	45499	2556
45500	45549	2559
45550	45599	2562
45600	45649	2566
45650	45699	2569
45700	45749	2572
45750	45799	2575
45800	45849	2579
45850	45899	2582
45900	45949	2585
45950	45999	2588
46000	46049	2592
46050	46099	2595
46100	46149	2598
46150	46199	2601
46200	46249	2605
46250	46299	2608
46300	46349	2611
46350	46399	2614
46400	46449	2618
46450	46499	2621
46500	46549	2624
46550	46599	2627
46600	46649	2631
46650	46699	2634
46700	46749	2637
46750	46799	2640
46800	46849	2644
46850	46899	2647
46900	46949	2650
46950	46999	2653
47000	47049	2657
47050	47099	2660
47100	47149	2663
47150	47199	2666
47200	47249	2670
47250	47299	2673
47300	47349	2676
47350	47399	2679
47400	47449	2683
47450	47499	2686
47500	47549	2689
47550	47599	2692
47600	47649	2696
47650	47699	2699
47700	47749	2702
47750	47799	2705
47800	47849	2709
47850	47899	2712
47900	47949	2715
47950	47999	2718
48000	48049	2722
48050	48099	2725
48100	48149	2728
48150	48199	2731
48200	48249	2735
48250	48299	2738
48300	48349	2741
48350	48399	2744
48400	48449	2748
48450	48499	2751
48500	48549	2754
48550	48599	2757
48600	48649	2761
48650	48699	2764
48700	48749	2767
48750	48799	2770
48800	48849	2774
48850	48899	2777
48900	48949	2780
48950	48999	2783
49000	49049	2787
49050	49099	2790
49100	49149	2793
49150	49199	2796
49200	49249	2800
49250	49299	2803
49300	49349	2806
49350	49399	2809
49400	49449	2813
49450	49499	2816
49500	49549	2819
49550	49599	2822
49600	49649	2826
49650	49699	2829
49700	49749	2832
49750	49799	2835
49800	49849	2839
49850	49899	2842
49900	49949	2845
49950	49999	2848
50000	50049	2852
50050	50099	2855
50100	50149	2858
50150	50199	2861
50200	50249	2865
50250	50299	2868
50300	50349	2871
50350	50399	2874
50400	50449	2878
50450	50499	2881
50500	50549	2884
50550	50599	2887
50600	50649	2891
50650	50699	2894
50700	50749	2897
50750	50799	2900
50800	50849	2904
50850	50899	2907
50900	50949	2910
50950	50999	2913
51000	51049	2917
51050	51099	2920
51100	51149	2923
51150	51199	2926
51200	51249	2930
51250	51299	2933
51300	51349	2936
51350	51399	2939
51400	51449	2943
51450	51499	2946
51500	51549	2949
51550	51599	2952
51600	51649	2956
51650	51699	2959
51700	51749	2962
51750	51799	2965
51800	51849	2969
51850	51899	2972
51900	51949	2975
51950	51999	2978
52000	52049	2982
52050	52099	2985
52100	52149	2988
52150	52199	2991
52200	52249	2995
52250	52299	2998
52300	52349	3001
52350	52399	3004
52400	52449	3008
52450	52499	3011
52500	52549	3014
52550	52599	3017
52600	52649	3021
52650	52699	3024
52700	52749	3027
52750	52799	3030
52800	52849	3034
52850	52899	3037
52900	52949	3040
52950	52999	3043
53000	53049	3047
53050	53099	3050
53100	53149	3053
53150	53199	3056
53200	53249	3060
53250	53299	3063
53300	53349	3066
53350	53399	3069
53400	53449	3073
53450	53499	3076
53500	53549	3079
53550	53599	3082
53600	53649	3086
53650	53699	3089
53700	53749	3092
53750	53799	3095
53800	53849	3099
53850	53899	3102
53900	53949	3105
53950	53999	3108
54000	54049	3112
54050	54099	3115
54100	54149	3118
54150	54199	3121
54200	54249	3125
54250	54299	3128
54300	54349	3131
54350	54399	3134
54400	54449	3138
54450	54499	3141
54500	54549	3144
54550	54599	3147
54600	54649	3151
54650	54699	3154
54700	54749	3157
54750	54799	3160
54800	54849	3164
54850	54899	3167
54900	54949	3170
54950	54999	3173
55000	55049	3177
55050	55099	3180
55100	55149	3183
55150	55199	3186
55200	55249	3190
55250	55299	3193
55300	55349	3196
55350	55399	3199
55400	55449	3203
55450	55499	3206
55500	55549	3209
55550	55599	3212
55600	55649	3216
55650	55699	3219
55700	55749	3222
55750	55799	3225
55800	55849	3229
55850	55899	3232
55900	55949	3235
55950	55999	3238
56000	56049	3242
56050	56099	3245
56100	56149	3248
56150	56199	3251
56200	56249	3255
56250	56299	3258
56300	56349	3261
56350	56399	3264
56400	56449	3268
56450	56499	3271
56500	56549	3274
56550	56599	3277
56600	56649	3281
56650	56699	3284
56700	56749	3287
56750	56799	3290
56800	56849	3294
56850	56899	3297
56900	56949	3300
56950	56999	3303
57000	57049	3307
57050	57099	3310
57100	57149	3313
57150	57199	3316
57200	57249	3320
57250	57299	3323
57300	57349	3326
57350	57399	3329
57400	57449	3333
57450	57499	3336
57500	57549	3339
57550	57599	3342
57600	57649	3346
57650	57699	3349
57700	57749	3352
57750	57799	3355
57800	57849	3359
57850	57899	3362
57900	57949	3365
57950	57999	3368
58000	58049	3372
58050	58099	3375
58100	58149	3378
58150	58199	3381
58200	58249	3385
58250	58299	3388
58300	58349	3391
58350	58399	3394
58400	58449	3398
58450	58499	3401
58500	58549	3404
58550	58599	3407
58600	58649	3411
58650	58699	3414
58700	58749	3417
58750	58799	3420
58800	58849	3424
58850	58899	3427
58900	58949	3430
58950	58999	3433
59000	59049	3437
59050	59099	3440
59100	59149	3443
59150	59199	3446
59200	59249	3450
59250	59299	3453
59300	59349	3456
59350	59399	3459
59400	59449	3463
59450	59499	3466
59500	59549	3469
59550	59599	3472
59600	59649	3476
59650	59699	3479
59700	59749	3482
59750	59799	3485
59800	59849	3489
59850	59899	3492
59900	59949	3495
59950	59999	3498
60000	60049	3501
60050	60099	3505
60100	60149	3510
60150	60199	3514
60200	60249	3518
60250	60299	3522
60300	60349	3527
60350	60399	3531
60400	60449	3535
60450	60499	3539
60500	60549	3544
60550	60599	3548
60600	60649	3552
60650	60699	3556
60700	60749	3561
60750	60799	3565
60800	60849	3569
60850	60899	3573
60900	60949	3578
60950	60999	3582
61000	61049	3586
61050	61099	3590
61100	61149	3595
61150	61199	3599
61200	61249	3603
61250	61299	3607
61300	61349	3612
61350	61399	3616
61400	61449	3620
61450	61499	3624
61500	61549	3629
61550	61599	3633
61600	61649	3637
61650	61699	3641
61700	61749	3646
61750	61799	3650
61800	61849	3654
61850	61899	3658
61900	61949	3663
61950	61999	3667
62000	62049	3671
62050	62099	3675
62100	62149	3680
62150	62199	3684
62200	62249	3688
62250	62299	3692
62300	62349	3697
62350	62399	3701
62400	62449	3705
62450	62499	3709
62500	62549	3714
62550	62599	3718
62600	62649	3722
62650	62699	3726
62700	62749	3731
62750	62799	3735
62800	62849	3739
62850	62899	3743
62900	62949	3748
62950	62999	3752
63000	63049	3756
63050	63099	3760
63100	63149	3765
63150	63199	3769
63200	63249	3773
63250	63299	3777
63300	63349	3782
63350	63399	3786
63400	63449	3790
63450	63499	3794
63500	63549	3799
63550	63599	3803
63600	63649	3807
63650	63699	3811
63700	63749	3816
63750	63799	3820
63800	63849	3824
63850	63899	3828
63900	63949	3833
63950	63999	3837
64000	64049	3841
64050	64099	3845
64100	64149	3850
64150	64199	3854
64200	64249	3858
64250	64299	3862
64300	64349	3867
64350	64399	3871
64400	64449	3875
64450	64499	3879
64500	64549	3884
64550	64599	3888
64600	64649	3892
64650	64699	3896
64700	64749	3901
64750	64799	3905
64800	64849	3909
64850	64899	3913
64900	64949	3918
64950	64999	3922
65000	65049	3926
65050	65099	3930
65100	65149	3935
65150	65199	3939
65200	65249	3943
65250	65299	3947
65300	65349	3952
65350	65399	3956
65400	65449	3960
65450	65499	3964
65500	65549	3969
65550	65599	3973
65600	65649	3977
65650	65699	3981
65700	65749	3986
65750	65799	3990
65800	65849	3994
65850	65899	3998
65900	65949	4003
65950	65999	4007
66000	66049	4011
66050	66099	4015
66100	66149	4020
66150	66199	4024
66200	66249	4028
66250	66299	4032
66300	66349	4037
66350	66399	4041
66400	66449	4045
66450	66499	4049
66500	66549	4054
66550	66599	4058
66600	66649	4062
66650	66699	4066
66700	66749	4071
66750	66799	4075
66800	66849	4079
66850	66899	4083
66900	66949	4088
66950	66999	4092
67000	67049	4096
67050	67099	4100
67100	67149	4105
67150	67199	4109
67200	67249	4113
67250	67299	4117
67300	67349	4122
67350	67399	4126
67400	67449	4130
67450	67499	4134
67500	67549	4139
67550	67599	4143
67600	67649	4147
67650	67699	4151
67700	67749	4156
67750	67799	4160
67800	67849	4164
67850	67899	4168
67900	67949	4173
67950	67999	4177
68000	68049	4181
68050	68099	4185
68100	68149	4190
68150	68199	4194
68200	68249	4198
68250	68299	4202
68300	68349	4207
68350	68399	4211
68400	68449	4215
68450	68499	4219
68500	68549	4224
68550	68599	4228
68600	68649	4232
68650	68699	4236
68700	68749	4241
68750	68799	4245
68800	68849	4249
68850	68899	4253
68900	68949	4258
68950	68999	4262
69000	69049	4266
69050	69099	4270
69100	69149	4275
69150	69199	4279
69200	69249	4283
69250	69299	4287
69300	69349	4292
69350	69399	4296
69400	69449	4300
69450	69499	4304
69500	69549	4309
69550	69599	4313
69600	69649	4317
69650	69699	4321
69700	69749	4326
69750	69799	4330
69800	69849	4334
69850	69899	4338
69900	69949	4343
69950	69999	4347
70000	70049	4351
70050	70099	4355
70100	70149	4360
70150	70199	4364
70200	70249	4368
70250	70299	4372
70300	70349	4377
70350	70399	4381
70400	70449	4385
70450	70499	4389
70500	70549	4394
70550	70599	4398
70600	70649	4402
70650	70699	4406
70700	70749	4411
70750	70799	4415
70800	70849	4419
70850	70899	4423
70900	70949	4428
70950	70999	4432
71000	71049	4436
71050	71099	4440
71100	71149	4445
71150	71199	4449
71200	71249	4453
71250	71299	4457
71300	71349	4462
71350	71399	4466
71400	71449	4470
71450	71499	4474
71500	71549	4479
71550	71599	4483
71600	71649	4487
71650	71699	4491
71700	71749	4496
71750	71799	4500
71800	71849	4504
71850	71899	4508
71900	71949	4513
71950	71999	4517
72000	72049	4521
72050	72099	4525
72100	72149	4530
72150	72199	4534
72200	72249	4538
72250	72299	4542
72300	72349	4547
72350	72399	4551
72400	72449	4555
72450	72499	4559
72500	72549	4564
72550	72599	4568
72600	72649	4572
72650	72699	4576
72700	72749	4581
72750	72799	4585
72800	72849	4589
72850	72899	4593
72900	72949	4598
72950	72999	4602
73000	73049	4606
73050	73099	4610
73100	73149	4615
73150	73199	4619
73200	73249	4623
73250	73299	4627
73300	73349	4632
73350	73399	4636
73400	73449	4640
73450	73499	4644
73500	73549	4649
73550	73599	4653
73600	73649	4657
73650	73699	4661
73700	73749	4666
73750	73799	4670
73800	73849	4674
73850	73899	4678
73900	73949	4683
73950	73999	4687
74000	74049	4691
74050	74099	4695
74100	74149	4700
74150	74199	4704
74200	74249	4708
74250	74299	4712
74300	74349	4717
74350	74399	4721
74400	74449	4725
74450	74499	4729
74500	74549	4734
74550	74599	4738
74600	74649	4742
74650	74699	4746
74700	74749	4751
74750	74799	4755
74800	74849	4759
74850	74899	4763
74900	74949	4768
74950	74999	4772
75000	75049	4776
75050	75099	4780
75100	75149	4785
75150	75199	4789
75200	75249	4793
75250	75299	4797
75300	75349	4802
75350	75399	4806
75400	75449	4810
75450	75499	4814
75500	75549	4819
75550	75599	4823
75600	75649	4827
75650	75699	4831
75700	75749	4836
75750	75799	4840
75800	75849	4844
75850	75899	4848
75900	75949	4853
75950	75999	4857
76000	76049	4861
76050	76099	4865
76100	76149	4870
76150	76199	4874
76200	76249	4878
76250	76299	4882
76300	76349	4887
76350	76399	4891
76400	76449	4895
76450	76499	4899
76500	76549	4904
76550	76599	4908
76600	76649	4912
76650	76699	4916
76700	76749	4921
76750	76799	4925
76800	76849	4929
76850	76899	4933
76900	76949	4938
76950	76999	4942
77000	77049	4946
77050	77099	4950
77100	77149	4955
77150	77199	4959
77200	77249	4963
77250	77299	4967
77300	77349	4972
77350	77399	4976
77400	77449	4980
77450	77499	4984
77500	77549	4989
77550	77599	4993
77600	77649	4997
77650	77699	5001
77700	77749	5006
77750	77799	5010
77800	77849	5014
77850	77899	5018
77900	77949	5023
77950	77999	5027
78000	78049	5031
78050	78099	5035
78100	78149	5040
78150	78199	5044
78200	78249	5048
78250	78299	5052
78300	78349	5057
78350	78399	5061
78400	78449	5065
78450	78499	5069
78500	78549	5074
78550	78599	5078
78600	78649	5082
78650	78699	5086
78700	78749	5091
78750	78799	5095
78800	78849	5099
78850	78899	5103
78900	78949	5108
78950	78999	5112
79000	79049	5116
79050	79099	5120
79100	79149	5125
79150	79199	5129
79200	79249	5133
79250	79299	5137
79300	79349	5142
79350	79399	5146
79400	79449	5150
79450	79499	5154
79500	79549	5159
79550	79599	5163
79600	79649	5167
79650	79699	5171
79700	79749	5176
79750	79799	5180
79800	79849	5184
79850	79899	5188
79900	79949	5193
79950	79999	5197
80000	80049	5201
80050	80099	5205
80100	80149	5210
80150	80199	5214
80200	80249	5218
80250	80299	5222
80300	80349	5227
80350	80399	5231
80400	80449	5235
80450	80499	5239
80500	80549	5244
80550	80599	5248
80600	80649	5252
80650	80699	5256
80700	80749	5261
80750	80799	5265
80800	80849	5269
80850	80899	5273
80900	80949	5278
80950	80999	5282
81000	81049	5286
81050	81099	5290
81100	81149	5295
81150	81199	5299
81200	81249	5303
81250	81299	5307
81300	81349	5312
81350	81399	5316
81400	81449	5320
81450	81499	5324
81500	81549	5329
81550	81599	5333
81600	81649	5337
81650	81699	5341
81700	81749	5346
81750	81799	5350
81800	81849	5354
81850	81899	5358
81900	81949	5363
81950	81999	5367
82000	82049	5371
82050	82099	5375
82100	82149	5380
82150	82199	5384
82200	82249	5388
82250	82299	5392
82300	82349	5397
82350	82399	5401
82400	82449	5405
82450	82499	5409
82500	82549	5414
82550	82599	5418
82600	82649	5422
82650	82699	5426
82700	82749	5431
82750	82799	5435
82800	82849	5439
82850	82899	5443
82900	82949	5448
82950	82999	5452
83000	83049	5456
83050	83099	5460
83100	83149	5465
83150	83199	5469
83200	83249	5473
83250	83299	5477
83300	83349	5482
83350	83399	5486
83400	83449	5490
83450	83499	5494
83500	83549	5499
83550	83599	5503
83600	83649	5507
83650	83699	5511
83700	83749	5516
83750	83799	5520
83800	83849	5524
83850	83899	5528
83900	83949	5533
83950	83999	5537
84000	84049	5541
84050	84099	5545
84100	84149	5550
84150	84199	5554
84200	84249	5558
84250	84299	5562
84300	84349	5567
84350	84399	5571
84400	84449	5575
84450	84499	5579
84500	84549	5584
84550	84599	5588
84600	84649	5592
84650	84699	5596
84700	84749	5601
84750	84799	5605
84800	84849	5609
84850	84899	5613
84900	84949	5618
84950	84999	5622
85000	85049	5626
85050	85099	5630
85100	85149	5635
85150	85199	5639
85200	85249	5643
85250	85299	5647
85300	85349	5652
85350	85399	5656
85400	85449	5660
85450	85499	5664
85500	85549	5669
85550	85599	5673
85600	85649	5677
85650	85699	5681
85700	85749	5686
85750	85799	5690
85800	85849	5694
85850	85899	5698
85900	85949	5703
85950	85999	5707
86000	86049	5711
86050	86099	5715
86100	86149	5720
86150	86199	5724
86200	86249	5728
86250	86299	5732
86300	86349	5737
86350	86399	5741
86400	86449	5745
86450	86499	5749
86500	86549	5754
86550	86599	5758
86600	86649	5762
86650	86699	5766
86700	86749	5771
86750	86799	5775
86800	86849	5779
86850	86899	5783
86900	86949	5788
86950	86999	5792
87000	87049	5796
87050	87099	5800
87100	87149	5805
87150	87199	5809
87200	87249	5813
87250	87299	5817
87300	87349	5822
87350	87399	5826
87400	87449	5830
87450	87499	5834
87500	87549	5839
87550	87599	5843
87600	87649	5847
87650	87699	5851
87700	87749	5856
87750	87799	5860
87800	87849	5864
87850	87899	5868
87900	87949	5873
87950	87999	5877
88000	88049	5881
88050	88099	5885
88100	88149	5890
88150	88199	5894
88200	88249	5898
88250	88299	5902
88300	88349	5907
88350	88399	5911
88400	88449	5915
88450	88499	5919
88500	88549	5924
88550	88599	5928
88600	88649	5932
88650	88699	5936
88700	88749	5941
88750	88799	5945
88800	88849	5949
88850	88899	5953
88900	88949	5958
88950	88999	5962
89000	89049	5966
89050	89099	5970
89100	89149	5975
89150	89199	5979
89200	89249	5983
89250	89299	5987
89300	89349	5992
89350	89399	5996
89400	89449	6000
89450	89499	6004
89500	89549	6009
89550	89599	6013
89600	89649	6017
89650	89699	6021
89700	89749	6026
89750	89799	6030
89800	89849	6034
89850	89899	6038
89900	89949	6043
89950	89999	6047
90000	90049	6051
90050	90099	6055
90100	90149	6060
90150	90199	6064
90200	90249	6068
90250	90299	6072
90300	90349	6077
90350	90399	6081
90400	90449	6085
90450	90499	6089
90500	90549	6094
90550	90599	6098
90600	90649	6102
90650	90699	6106
90700	90749	6111
90750	90799	6115
90800	90849	6119
90850	90899	6123
90900	90949	6128
90950	90999	6132
91000	91049	6136
91050	91099	6140
91100	91149	6145
91150	91199	6149
91200	91249	6153
91250	91299	6157
91300	91349	6162
91350	91399	6166
91400	91449	6170
91450	91499	6174
91500	91549	6179
91550	91599	6183
91600	91649	6187
91650	91699	6191
91700	91749	6196
91750	91799	6200
91800	91849	6204
91850	91899	6208
91900	91949	6213
91950	91999	6217
92000	92049	6221
92050	92099	6225
92100	92149	6230
92150	92199	6234
92200	92249	6238
92250	92299	6242
92300	92349	6247
92350	92399	6251
92400	92449	6255
92450	92499	6259
92500	92549	6264
92550	92599	6268
92600	92649	6272
92650	92699	6276
92700	92749	6281
92750	92799	6285
92800	92849	6289
92850	92899	6293
92900	92949	6298
92950	92999	6302
93000	93049	6306
93050	93099	6310
93100	93149	6315
93150	93199	6319
93200	93249	6323
93250	93299	6327
93300	93349	6332
93350	93399	6336
93400	93449	6340
93450	93499	6344
93500	93549	6349
93550	93599	6353
93600	93649	6357
93650	93699	6361
93700	93749	6366
93750	93799	6370
93800	93849	6374
93850	93899	6378
93900	93949	6383
93950	93999	6387
94000	94049	6391
94050	94099	6395
94100	94149	6400
94150	94199	6404
94200	94249	6408
94250	94299	6412
94300	94349	6417
94350	94399	6421
94400	94449	6425
94450	94499	6429
94500	94549	6434
94550	94599	6438
94600	94649	6442
94650	94699	6446
94700	94749	6451
94750	94799	6455
94800	94849	6459
94850	94899	6463
94900	94949	6468
94950	94999	6472
95000	95049	6476
95050	95099	6480
95100	95149	6485
95150	95199	6489
95200	95249	6493
95250	95299	6497
95300	95349	6502
95350	95399	6506
95400	95449	6510
95450	95499	6514
95500	95549	6519
95550	95599	6523
95600	95649	6527
95650	95699	6531
95700	95749	6536
95750	95799	6540
95800	95849	6544
95850	95899	6548
95900	95949	6553
95950	95999	6557
96000	96049	6561
96050	96099	6565
96100	96149	6570
96150	96199	6574
96200	96249	6578
96250	96299	6582
96300	96349	6587
96350	96399	6591
96400	96449	6595
96450	96499	6599
96500	96549	6604
96550	96599	6608
96600	96649	6612
96650	96699	6616
96700	96749	6621
96750	96799	6625
96800	96849	6629
96850	96899	6633
96900	96949	6638
96950	96999	6642
97000	97049	6646
97050	97099	6650
97100	97149	6655
97150	97199	6659
97200	97249	6663
97250	97299	6667
97300	97349	6672
97350	97399	6676
97400	97449	6680
97450	97499	6684
97500	97549	6689
97550	97599	6693
97600	97649	6697
97650	97699	6701
97700	97749	6706
97750	97799	6710
97800	97849	6714
97850	97899	6718
97900	97949	6723
97950	97999	6727
98000	98049	6731
98050	98099	6735
98100	98149	6740
98150	98199	6744
98200	98249	6748
98250	98299	6752
98300	98349	6757
98350	98399	6761
98400	98449	6765
98450	98499	6769
98500	98549	6774
98550	98599	6778
98600	98649	6782
98650	98699	6786
98700	98749	6791
98750	98799	6795
98800	98849	6799
98850	98899	6803
98900	98949	6808
98950	98999	6812
99000	99049	6816
99050	99099	6820
99100	99149	6825
99150	99199	6829
99200	99249	6833
99250	99299	6837
99300	99349	6842
99350	99399	6846
99400	99449	6850
99450	99499	6854
99500	99549	6859
99550	99599	6863
99600	99649	6867
99650	99699	6871
99700	99749	6876
99750	99799	6880
99800	99849	6884
99850	99899	6888
99900	99949	6893
99950	99999	6897
100000	100000	6901
EOF
end