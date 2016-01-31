function [grad_W_rnn, grad_W_emb, emb_indices] = srcCharLayerBackprop(W_rnn, charData, charGrad)
% Backprop for char layer from word gradients to chars.
% Input:
%   W_rnn: recurrent connections of multiple layers, e.g., W_rnn{ll}.
%
% Thang Luong @ 2015, <lmthang@stanford.edu>

  assert(length(charGrad.indices) == charData.numRareWords);
  
  params = charData.params;
  if params.assert
    assert(isequal(sort(charData.rareWordMap(charGrad.indices))', 1:charData.numRareWords));
  end
  
  if params.debug
    fprintf(2, '# srcCharLayerBackprop before, %s\n', gpuInfo(params.gpu));
  end
  
  topGrads = cell(charData.maxLen, 1);
  topGrads{end} = charGrad.embs(:, charData.rareWordMap(charGrad.indices));

  % init state
  zeroBatch = zeroMatrix([params.lstmSize, params.curBatchSize], params.isGPU, params.dataType);
  zeroState = cell(params.numLayers, 1);
  zeroGrad = cell(params.numLayers, 1);
  for ll=1:params.numLayers % layer
    zeroState{ll}.h_t = zeroBatch;
    zeroState{ll}.c_t = zeroBatch;
    zeroGrad{ll} = zeroBatch;
  end
  
  [~, ~, grad_W_rnn, grad_W_emb, emb_indices, ~, ~, ~] = rnnLayerBackprop(W_rnn, charData.states, zeroState, ...
  topGrads, zeroGrad, zeroGrad, charData.batch, charData.mask, charData.params, charData.rnnFlags, [], [], []);

  if params.debug
    fprintf(2, '  after, %s\n', gpuInfo(params.gpu));
  end
  
  % [grad_W_rnn, grad_W_emb, emb_indices] = srcCharMultiBatchBackprop(W_rnn, charData, charGrad);    
end

% function [grad_W_rnn, grad_W_emb, emb_indices] = srcCharMultiBatchBackprop(W_rnn, charData, charGrad)
%   params = charData.batches{1}.params;
%   zeroBatch = zeroMatrix([params.lstmSize, params.curBatchSize], params.isGPU, params.dataType);
%   zeroState = cell(params.numLayers, 1);
%   zeroGrad = cell(params.numLayers, 1);
%   for ll=1:params.numLayers % layer
%     zeroState{ll}.h_t = zeroBatch;
%     zeroState{ll}.c_t = zeroBatch;
%     zeroGrad{ll} = zeroBatch;
%   end
%   curBatchSize = params.curBatchSize;
% 
%   topGrads_emb = charGrad.embs(:, charData.rareWordMap(charGrad.indices));
%   topGrads_emb = topGrads_emb(:, charData.sortedIndices); % since we sorted the sequences before
%   grad_W_emb = zeroMatrix([params.lstmSize, charData.numRareWords*10], params.isGPU, params.dataType);
%   emb_indices = zeros(charData.numRareWords*10, 1);
%   charCount = 0;
%   
%   % split into batches
%   count = 0;
%   for ii=1:charData.numBatches
%     batchCharData = charData.batches{ii};
%     params = batchCharData.params;
%     topGrads = cell(batchCharData.maxLen, 1);
%     topGrads{end} = topGrads_emb(:, count+1:count+params.curBatchSize);
%     count = count+params.curBatchSize;
%     
%     if params.curBatchSize ~= curBatchSize
%       assert(ii == charData.numBatches);
%       zeroBatch = zeroMatrix([params.lstmSize, params.curBatchSize], params.isGPU, params.dataType);
%       for ll=1:params.numLayers % layer
%         zeroState{ll}.h_t = zeroBatch;
%         zeroState{ll}.c_t = zeroBatch;
%         zeroGrad{ll} = zeroBatch;
%       end
%     end
%     
%     [~, ~, grad_W_rnn_batch, grad_W_emb_batch, emb_indices_batch, ~, ~, ~] = rnnLayerBackprop(W_rnn, batchCharData.states, zeroState, ...
%       topGrads, zeroGrad, zeroGrad, batchCharData.batch, batchCharData.mask, batchCharData.params, batchCharData.rnnFlags, [], [], []);
%     
%     if ii==1
%       grad_W_rnn = grad_W_rnn_batch;
%     else
%       for ll=1:length(grad_W_rnn)
%         grad_W_rnn{ll} = grad_W_rnn{ll} + grad_W_rnn_batch{ll};
%       end
%     end
%     
%     % char emb
%     numDistinctChars = length(emb_indices_batch);
%     grad_W_emb(:, charCount+1:charCount+numDistinctChars) = grad_W_emb_batch;
%     emb_indices(charCount+1:charCount+numDistinctChars) = emb_indices_batch;
%     charCount = charCount + numDistinctChars;
%   end
%   assert(count == charData.numRareWords);
%   
%   % aggregate embs
%   grad_W_emb(:, charCount+1:end) = [];
%   emb_indices(charCount+1:end) = [];
%   [grad_W_emb, emb_indices] = aggregateMatrix(grad_W_emb, emb_indices, params.isGPU, params.dataType);
% end

%   if params.assert % multi batch
%     [grad_W_rnn1, grad_W_emb1, emb_indices1] = srcCharMultiBatchBackprop(W_rnn, charData1, charGrad);
%     for ll=1:length(grad_W_rnn)
%       assert(sum(abs(grad_W_rnn{ll}(:) - grad_W_rnn1{ll}(:))) < 1e-10);
%     end
%     assert(sum(abs(grad_W_emb(:) - grad_W_emb1(:))) < 1e-10);
%     assert(isequal(emb_indices, emb_indices1));
%   end