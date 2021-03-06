T=5.0

MODEL_PATH=checkpoints/models/SLSTM-TLSTM-6layers-layerwiseglobal-nonlinear-fp16
MODEL_PATH=checkpoints/models/SLSTM-TLSTM-6layers-layerwiseglobal-test-fp16
MODEL_PATH=checkpoints/models/SLSTM-TLSTM-6layers-mergelayer1head-test-fp16

dev=1
BASE=$(dirname $(pwd))
DATA_BASE=$(dirname $(dirname $(pwd)))/data
RUN_PATH=$BASE/fairseq_cli
export CUDA_VISIBLE_DEVICES=$dev
export PYTHONPATH=$BASE
mode=$1

if [ "$mode" == "prepare" ]
then

# Preprocess/binarize the data
TEXT=$BASE/examples/translation/iwslt14.tokenized.de-en
python $RUN_PATH/preprocess.py --source-lang de --target-lang en \
    --trainpref $TEXT/train --validpref $TEXT/valid --testpref $TEXT/test \
    --destdir data-bin/iwslt14_deen_s8000t6000 \
    --workers 20

elif [ "$mode" == "train" ]
then
echo "Start training..."
mkdir -p $MODEL_PATH

CUDA_VISIBLE_DEVICES=0,1,2,3 python -u $RUN_PATH/train.py  \
    data-bin/iwslt14_deen_s8000t6000 \
    --arch slstm_tlstm --share-decoder-input-output-embed \
    --optimizer adam --adam-betas '(0.9, 0.98)' --clip-norm 0.0 \
    --lr 5e-4 --lr-scheduler inverse_sqrt --warmup-updates 4000 \
    --dropout 0.3 --weight-decay 0.0001 \
    --criterion label_smoothed_cross_entropy --label-smoothing 0.1 \
    --max-update 200000 --max-epoch 200 \
    --patience 50 \
    --attention-dropout 0.1 \
    --max-tokens 4096 \
    --update-freq 1 \
    --temperature $T \
    --encoder-layers 6 \
    --decoder-layers 6 \
	--kernel-size 1 \
    --no-epoch-checkpoints \
    --use-layerwise-global \
	--mask_dummy_for_fgate \
	--merge_layer \
	--ffoncell \
    --save-dir $MODEL_PATH 2>&1 | tee $MODEL_PATH/train.log

elif [ "$mode" == "test" ]
then
PYTHONIOENCODING=utf-8 python -u $RUN_PATH/generate.py data-bin/iwslt14_deen_s8000t6000 \
    --path $MODEL_PATH/checkpoint_best.pt \
    --batch-size 512 --beam 5 --remove-bpe --fp16 --lenpen 1.0 | tee $MODEL_PATH/test.log
fi
