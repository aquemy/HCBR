
def reduce_precision(value, prec=2):
    return "{:.{}f}".format(round(float(value), prec), prec)

def reduce_case_precision(case, prec=2, columns=[]):
    for i, f in enumerate(case):
        if columns is None or i in columns:
            case[i] = reduce_precision(f, prec)
    return case

def reduce_casecase_precision(casebase, prec, columns=[]):
    for i, c in enumerate(casebase):
        casebase[i] = reduce_case_precision(c, prec, columns)
    return casebase