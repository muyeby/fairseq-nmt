dev=1
BASE=$(dirname $(pwd))
DATA_BASE=$(dirname $(dirname $(pwd)))/data
RUN_PATH=$BASE/fairseq_cli
export CUDA_VISIBLE_DEVICES=$dev
export PYTHONPATH=$BASE
mode=$1
arch=grutransformer_iwslt_de_en
MODEL_PATH=checkpoints/${arch}-ff

if [ "$mode" == "train" ]
then
echo "Start training..."
mkdir -p $MODEL_PATH
CUDA_VISIBLE_DEVICES=0,1,2,3 nohup python -u $RUN_PATH/train.py \
    data-bin/iwslt14_deen_s8000t6000 \
    --arch $arch --share-decoder-input-output-embed \
    --optimizer adam --adam-betas '(0.9, 0.98)' --clip-norm 0.0 \
    --lr 5e-4 --lr-scheduler inverse_sqrt --warmup-updates 4000 \
    --dropout 0.3 --weight-decay 0.0001 \
    --criterion label_smoothed_cross_entropy --label-smoothing 0.1 \
    --max-tokens 4096 \
    --max-update 200000 --max-epoch 500 \
    --save-interval-updates 10000 --keep-interval-updates 20 \
    --find-unused-parameters \
    --fp16 \
    --no-epoch-checkpoints \
    --save-dir $MODEL_PATH > $MODEL_PATH/train.log 2>&1 &
elif [ "$mode" == "test" ]
then
PYTHONIOENCODING=utf-8 python -u $RUN_PATH/generate.py data-bin/iwslt14_deen_s8000t6000 \
    --path $MODEL_PATH/checkpoint_best.pt \
    --batch-size 512 --beam 5 --remove-bpe --fp16 --lenpen 0.6 | tee $MODEL_PATH/test.log
fi
