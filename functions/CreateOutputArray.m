function A = CreateOutputArray(signal, FPT_MultiChannel)
% signal: NxM (M leads)
% FPT_MultiChannel: KxP from ECGdeli

N = size(signal,1);
M = size(signal,2);

A = zeros(N, M + 6);
A(:, 1:M) = signal;

F = FPT_MultiChannel;

% --- Heuristique: si on voit des 0 mais aussi des valeurs proches de N-1,
% c'est probablement du 0-based -> +1.
mx = max(F(:), [], 'omitnan');
if ~isempty(mx) && isfinite(mx) && mx <= (N-1) && any(F(:)==0)
    F = F + 1;
end

% Remplace 0 (souvent "non détecté") par NaN pour ignorer
F(F==0) = NaN;

for i = 1:size(F,1)

    % P-wave: onset(1) .. offset(3), peak(2)
    A = mark_interval(A, F(i,1), F(i,3), M+1, N);
    A = mark_point(A,    F(i,2),       M+2, N);

    % QRS: onset(4) .. offset(8), R-peak(6)
    A = mark_interval(A, F(i,4), F(i,8), M+3, N);
    A = mark_point(A,    F(i,6),       M+4, N);

    % T-wave: onset(10) .. offset(12), peak(11)
    A = mark_interval(A, F(i,10), F(i,12), M+5, N);
    A = mark_point(A,     F(i,11),        M+6, N);
end
end

function A = mark_interval(A, s, e, col, N)
if ~(isfinite(s) && isfinite(e)), return; end
s = round(s); e = round(e);
s = max(1, min(N, s));
e = max(1, min(N, e));
if s > e, return; end
A(s:e, col) = 1;
end

function A = mark_point(A, p, col, N)
if ~isfinite(p), return; end
p = round(p);
p = max(1, min(N, p));
A(p, col) = 1;
end
