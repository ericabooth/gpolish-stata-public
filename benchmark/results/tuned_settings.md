# Tuned settings for ggrepel and adjustText

Written by `tune_others.py`: the setting with the highest mean clean-and-near share on the tuning scenarios (synthetic seeds 101 to 110), the objective `tune.py` used for `gpolish`.

- ggrepel: `BENCH_GG_PARMS="box.padding=0.25;point.padding=0;force=4;force_pull=0.5"` (objective 0.9183, clean share 0.9289, 256 settings)
- adjusttext: `BENCH_AT_PARMS="expand=1.2,1.6;force_text=0.05,0.1;force_static=0.4,0.8;force_pull=0.005,0.005;iter_lim=100"` (objective 0.7761, clean share 0.8450, 512 settings)
