#include "Owner.mqh"

Owner::Owner()
{
    axonsL1 = new CXArrayList<Axon*>;
    axonsL2 = new CXArrayList<Axon*>;
    axonsL3 = new CXArrayList<Axon*>;
    MathSrand(GetTickCount());
}
Owner::~Owner()
{
    delete softmax;
    delete trainer;
    Print("deleting axons: ",axonsL1.Count(),"+",axonsL2.Count(),"+",axonsL3.Count());
    for(int i=0; i<axonsL1.Count(); i++)
        delete axonsL1.at(i);
    for(int i=0; i<axonsL2.Count(); i++)
        delete axonsL2.at(i);
    for(int i=0; i<axonsL3.Count(); i++)
        delete axonsL3.at(i);
    for(int i=0; i<neuronsL1.Count(); i++)
        delete neuronsL1.at(i);
    for(int i=0; i<neuronsL2.Count(); i++)
        delete neuronsL2.at(i);
    for(int i=0; i<features.Count(); i++)
        delete features.at(i);
    delete axonsL1;
    delete axonsL2; 
    delete axonsL3; 
    delete eval;
    delete accDir;
    delete accAnalog;
    delete quality;

    Print("deleting done");
}
void Owner::CreateNN(Market* m, axon_value_t axon_method, double min_sm)
{
    FeatureFactory ff;
    NeuronFactory nf;
    
//==================Features & AxonsL1
    {
        string str;
        int req;
        req = db.CreateRequest("AxonsL1");
        str = db.ReadNextString(req);
        while(str!=DB_END_STR)
        {
            assert(str!=DB_ERROR_STR,"DB ERROR IN NN");
            bool neg=false;
            if(str[0]=='-')
            {   //negate the axon
                str=StringSubstr(str,1);
                neg=true;
            }
            string tempstr[3],name;
            bool freeze;
            double init;
            int splitcnt = StringSplit(str,'=',tempstr);
            switch(splitcnt)
            {
                case 1:   //normal Axon
                    name = tempstr[0];
                    freeze = false;
                    init = AXON_FLOOR;
                    break;
                case 2:   //active Axon, but with init value
                    name = tempstr[0];
                    freeze = false;
                    init = StringToDouble(tempstr[1]);
                    break;
                case 3:   //frozen Axon
                    assert(tempstr[1]=="F" || tempstr[1]=="f", "Axon is not frozen");
                    name = tempstr[0];
                    freeze = true;
                    init = StringToDouble(tempstr[2]);
                    break;
                 default:
                    freeze = true;
                    init = 0;
                    assert(false,"wrong Axon format");
                    break;
            }
            features.AddIfNotFound(ff.FeatureInstance(name));
            int feNo = features.IndexOf(ff.FeatureInstance(name));
            assert(feNo>=0 && feNo<features.Count(), "wrong feature no");
            axonsL1.Add( new Axon(ff.FeatureInstance(name), feNo, neg, freeze, init, RATE_DEGRADATION, RATE_GROWTH, AXON_FLOOR, AXON_CEILING, axon_method) );
            str = db.ReadNextString(req);
        };
        for(int i=0; i<features.Count(); i++)
            features.at(i).market = m;
        db.FinaliseRequest(req);
        Print(features.Count()," features created");
        Print(axonsL1.Count()," Axons(L1) created");
    }
//==================NeuronsL1
    {
        string str;
        int req;
        Neuron* ne = NULL;
        int index = 0;
        string tempstr[2];
        //int splitcnt;
        req = db.CreateRequest("NeuronsL1");
        str = db.ReadNextString(req);
        while(str!=DB_END_STR)
        {
            assert(str!=DB_ERROR_STR,"DB ERROR IN NN");
            if(str=="+")
                ne.AddAxon(axonsL1.at(index));
            else
            {                
                int splitcnt = StringSplit(str,'=',tempstr);
                assert(splitcnt==2,"wrong neuron format in NN");
                ne = nf.CreateNeuron(tempstr[0],tempstr[1]);
                ne.AddAxon(axonsL1.at(index));
                neuronsL1.Add(ne);
            }
            str = db.ReadNextString(req);
            index++;
        };
        db.FinaliseRequest(req);
        Print(neuronsL1.Count()," Neurons(L1) created");
    }
//==================AxonsL2
    {
        string str;
        int req;
        int index = -1;
        Neuron* ne=NULL;
        req = db.CreateRequest("AxonsL2");
        str = db.ReadNextString(req);
        while(str!=DB_END_STR)
        {
            assert(str!=DB_ERROR_STR,"DB ERROR IN NN");
            bool neg=false;
            if(str[0]=='-')
            {   //negate the axon
                str=StringSubstr(str,1);
                neg=true;
            }
            string tempstr[3],name;
            bool freeze;
            double init;
            int splitcnt = StringSplit(str,'=',tempstr);
            switch(splitcnt)
            {
                case 1:   //normal Axon
                    name = tempstr[0];
                    freeze = false;
                    init = AXON_FLOOR;
                    break;
                case 2:   ////active Axon, but with init value
                    name = tempstr[0];
                    freeze = false;
                    init = StringToDouble(tempstr[1]);
                    break;
                case 3:   //frozen Axon
                    assert(tempstr[1]=="F" || tempstr[1]=="f", "Axon is not frozen");
                    name = tempstr[0];
                    freeze = true;
                    init = StringToDouble(tempstr[2]);
                    break;
                 default:
                    freeze = true;
                    init = 0;
                    assert(false,"wrong Axon format");
                    break;
            }
            ne = nf.FindNeuronByName(name, &neuronsL1, index);
            assert(index!=-1 && ne!=NULL,"neuron not found in NN");
            axonsL2.Add(new Axon(ne, index, neg, freeze, init, RATE_DEGRADATION, RATE_GROWTH, AXON_FLOOR, AXON_CEILING, axon_method));

            str = db.ReadNextString(req);
        };
        db.FinaliseRequest(req);
        Print(axonsL2.Count()," Axons(L2) created");
    }
//==================NeuronsL2
    {
        string str;
        int req;
        Neuron* ne = NULL;
        int index = 0;
        string tempstr[2];
        //int splitcnt;
        req = db.CreateRequest("NeuronsL2");
        str = db.ReadNextString(req);
        while(str!=DB_END_STR)
        {
            assert(str!=DB_ERROR_STR,"DB ERROR IN NN");
            if(str=="+")
                ne.AddAxon(axonsL2.at(index));
            else
            {                
                int splitcnt = StringSplit(str,'=',tempstr);
                assert(splitcnt==2,"wrong neuron format in NN");
                ne = nf.CreateNeuron(tempstr[0],tempstr[1]);
                ne.AddAxon(axonsL2.at(index));
                neuronsL2.Add(ne);
            }
            str = db.ReadNextString(req);
            index++;
        };
        db.FinaliseRequest(req);
        Print(neuronsL2.Count()," Neurons(L2) created");
    }
//==================AxonsL3
    {
        for(int i=0; i<neuronsL2.Count(); i++)
            axonsL3.Add( new Axon(neuronsL2.at(i), i, false, false, AXON_FLOOR, RATE_DEGRADATION, RATE_GROWTH, AXON_FLOOR, AXON_CEILING, axon_method) );
        Print(axonsL3.Count()," Axons(L3) created");
    }
//==================Softmax
    {
        softmax = new NeuronSUM("softmax");
        for(int i=0; i<axonsL3.Count(); i++)
            softmax.AddAxon(axonsL3.at(i));
    }
//==================Others
    accDir = new AccuracyDirection();
    accAnalog = new AccuracyAnalog();
    eval = new Evaluator();
    trainer = new Trainer(softmax, eval, axonsL1, axonsL2, axonsL3);
    quality = new QualityMetrics(min_sm);

}

void Owner::UpdateInput(const double& c[], const double& d[], int len)
{
    for(int i=0; i<features.Count(); i++)
        ((Feature*)(features.at(i))).Update(c, d, len);
}
void Owner::Train1Epoch(double desired, double desired_scaled, evaluation_method_t evm)
{
    switch(evm)
    {
        case METHOD_DIRECTION:
            trainer.Go1Epoch(desired,accDir);
            trainer.ApplyAxonChanges(true, desired_scaled);
            break;
        case METHOD_ANALOG_DISTANCE:
            trainer.Go1Epoch(desired,accAnalog);
            trainer.ApplyAxonChanges(false, 0);
            break;
        case METHOD_ALL:
            trainer.Go1Epoch(desired,accDir);
            trainer.ApplyAxonChanges(true, desired_scaled);
            trainer.Go1Epoch(desired,accAnalog);
            trainer.ApplyAxonChanges(false, 0);
            break;
        default:
            assert(false,"unknown accuracy method");
    }
}
trade_advice_t Owner::GetAdvice()
{
    return TRADE_NONE;
}
bool Owner::CreateDebugDB(DEBUG_MODE debug_m)
{
    if(debug_m == DEBUG_NONE)
        return true;
    db.AddDBGTBLItem("time", false);
    db.AddDBGTBLItem("desired", false);
    db.AddDBGTBLItem("softmax",false);
    if(debug_m==DEBUG_VERBOSE)
    {
        db.AddDBGTBLItem("DiffShort", false);
        db.AddDBGTBLItem("DiffLong", false);
        db.AddDBGTBLItem("DiffAll", false);
        db.AddDBGTBLItem("DirShort", false);
        db.AddDBGTBLItem("DirLong", false);
    }
    db.AddDBGTBLItem("Dirpc", false);
    if(debug_m==DEBUG_VERBOSE)
    {
        db.AddDBGTBLItem("ProfitShort", false);
        db.AddDBGTBLItem("ProfitLong", false);
    }
    db.AddDBGTBLItem("ProfitAll", false);
    db.AddDBGTBLItem("ProfitAve", false);
    if(debug_m==DEBUG_VERBOSE)
        for(int i=0; i<features.Count(); i++)
            db.AddDBGTBLItem(features.at(i).name,false);
    for(int i=0; i<axonsL1.Count(); i++)
    {
        db.AddDBGTBLItem("X"+IntegerToString(i,2,'0')+"_"+axonsL1.at(i).pnode.name,false);
        if(debug_m==DEBUG_VERBOSE || debug_m==DEBUG_INTERVAL_100)
            db.AddDBGTBLItem("X"+IntegerToString(i,2,'0')+"p",false);
    }
    if(debug_m==DEBUG_VERBOSE)
        for(int i=0; i<neuronsL1.Count(); i++)
            db.AddDBGTBLItem("N"+"_"+neuronsL1.at(i).name,false);
    for(int i=0; i<axonsL2.Count(); i++)
    {
        db.AddDBGTBLItem("Y"+IntegerToString(i,2,'0')+"_"+axonsL2.at(i).pnode.name,false);
        if(debug_m==DEBUG_VERBOSE || debug_m==DEBUG_INTERVAL_100)
            db.AddDBGTBLItem("y"+IntegerToString(i,2,'0')+"p",false);
    }
    if(debug_m==DEBUG_VERBOSE)
        for(int i=0; i<neuronsL2.Count(); i++)
            db.AddDBGTBLItem("N"+"_"+neuronsL2.at(i).name,false);
    for(int i=0; i<axonsL3.Count(); i++)
    {
        db.AddDBGTBLItem("Z"+IntegerToString(i,2,'0')+"_"+axonsL3.at(i).pnode.name,false);
        if(debug_m==DEBUG_VERBOSE || debug_m==DEBUG_INTERVAL_100)
            db.AddDBGTBLItem("Z"+IntegerToString(i,2,'0')+"p",false);
    }
    db.AddDBGTBLItem("diff_raw", false);
    db.AddDBGTBLItem("close_raw", false);
    return db.AddDBGTBLItem("reserve", true);
}
bool Owner::CreateStateDB()
{
    return true;
}
void Owner::SaveDebugInfo(DEBUG_MODE debug_m, int index, double desired_in, double diff_raw1, double close1, datetime time1)
{
    if(debug_m == DEBUG_NONE)
        return;
    if(debug_m == DEBUG_INTERVAL_10)
        if(index%10 != 0)
            return;
    if(debug_m == DEBUG_INTERVAL_100)
        if(index%100 != 0)
            return;
    db.Insert("ID", (double)index, false);    
    db.Insert("time", (double)time1, false);
    db.Insert("desired", desired_in, false);
    db.Insert("softmax", softmax.GetNode(), false);
    if(debug_m==DEBUG_VERBOSE)
    {
        db.Insert("DiffShort", quality.GetQuality(QUALITY_METHOD_DIFF,QUALITY_PERIOD_SHORT), false);
        db.Insert("DiffLong", quality.GetQuality(QUALITY_METHOD_DIFF,QUALITY_PERIOD_LONG), false);
        db.Insert("DiffAll", quality.GetQuality(QUALITY_METHOD_DIFF,QUALITY_PERIOD_ALLTIME), false);
        db.Insert("DirShort", quality.GetQuality(QUALITY_METHOD_DIRECTION,QUALITY_PERIOD_SHORT), false);
        db.Insert("DirLong", quality.GetQuality(QUALITY_METHOD_DIRECTION,QUALITY_PERIOD_LONG), false);
    }
    db.Insert("Dirpc", quality.GetQuality(QUALITY_METHOD_DIRECTION,QUALITY_PERIOD_ALLTIME), false);
    if(debug_m==DEBUG_VERBOSE)
    {
        db.Insert("ProfitShort", quality.GetQuality(QUALITY_METHOD_PROFIT,QUALITY_PERIOD_SHORT), false);
        db.Insert("ProfitLong", quality.GetQuality(QUALITY_METHOD_PROFIT,QUALITY_PERIOD_LONG), false);
    }
    db.Insert("ProfitAll", quality.GetQuality(QUALITY_METHOD_PROFIT,QUALITY_PERIOD_ALLTIME), false);
    db.Insert("ProfitAve", quality.GetQuality(QUALITY_METHOD_PROFIT,QUALITY_PERIOD_AVEALL), false);
    if(debug_m==DEBUG_VERBOSE)
        for(int i=0; i<features.Count(); i++)
            db.Insert(features.at(i).name, features.at(i).GetNode(), false);
    for(int i=0; i<axonsL1.Count(); i++)
    {
        db.Insert("X"+IntegerToString(i,2,'0')+"_"+axonsL1.at(i).pnode.name, axonsL1.at(i).GetGain(), false);
        if(debug_m==DEBUG_VERBOSE || debug_m==DEBUG_INTERVAL_100)
            db.Insert("X"+IntegerToString(i,2,'0')+"p", axonsL1.at(i).GetProfit(), false);
    }
    if(debug_m==DEBUG_VERBOSE)
        for(int i=0; i<neuronsL1.Count(); i++)
            db.Insert("N"+"_"+neuronsL1.at(i).name, neuronsL1.at(i).GetNode(), false);
    for(int i=0; i<axonsL2.Count(); i++)
    {
        db.Insert("Y"+IntegerToString(i,2,'0')+"_"+axonsL2.at(i).pnode.name, axonsL2.at(i).GetGain(), false);
        if(debug_m==DEBUG_VERBOSE || debug_m==DEBUG_INTERVAL_100)
            db.Insert("Y"+IntegerToString(i,2,'0')+"p", axonsL2.at(i).GetProfit(), false);
    }
    if(debug_m==DEBUG_VERBOSE)
        for(int i=0; i<neuronsL2.Count(); i++)
            db.Insert("N"+"_"+neuronsL2.at(i).name, neuronsL2.at(i).GetNode(), false);
    for(int i=0; i<axonsL3.Count(); i++)
    {
        db.Insert("Z"+IntegerToString(i,2,'0')+"_"+axonsL3.at(i).pnode.name, axonsL3.at(i).GetGain(), false);
        if(debug_m==DEBUG_VERBOSE || debug_m==DEBUG_INTERVAL_100)
            db.Insert("Z"+IntegerToString(i,2,'0')+"p", axonsL3.at(i).GetProfit(), false);
    }
    db.Insert("diff_raw", diff_raw1, false);
    db.Insert("close_raw", close1, false);
    db.Insert("reserve", 0, true);
}
void Owner::UpdateAxonStats()
{
    bestL1=axonsL1.at(0);
    bestL1Profit=axonsL1.at(0);
    for(int i=0; i<axonsL1.Count(); i++)
    {
        axonsL1.at(i).UpdateAve();
        if(axonsL1.at(i).GetAve() > bestL1.GetAve())
            bestL1=axonsL1.at(i);
        if(axonsL1.at(i).GetProfit() > bestL1Profit.GetProfit() )
            bestL1Profit=axonsL1.at(i);
    }
    bestL2=axonsL2.at(0);
    bestL2Profit=axonsL2.at(0);
    for(int i=0; i<axonsL2.Count(); i++)
    {
        axonsL2.at(i).UpdateAve();
        if(axonsL2.at(i).GetAve() > bestL2.GetAve())
            bestL2=axonsL2.at(i);
        if(axonsL2.at(i).GetProfit() > bestL2Profit.GetProfit() )
            bestL2Profit=axonsL2.at(i);
    }
    bestL3=axonsL3.at(0);
    bestL3Profit=axonsL3.at(0);
    for(int i=0; i<axonsL3.Count(); i++)
    {
        axonsL3.at(i).UpdateAve();
        if(axonsL3.at(i).GetAve() > bestL3.GetAve())
            bestL3=axonsL3.at(i);
         if(axonsL3.at(i).GetProfit() > bestL3Profit.GetProfit() )
            bestL3Profit=axonsL3.at(i);
   } 
}
string Owner::GetAxonsReport()
{
    string temp = bestL1.pnode.name + "(" + IntegerToString(bestL1.node_id)+")=" + DoubleToString(bestL1.GetAve(),2)+"," + DoubleToString(bestL1.GetProfit(),2);
    temp += "..."+bestL1Profit.pnode.name + "(" + IntegerToString(bestL1Profit.node_id)+")=" + DoubleToString(bestL1Profit.GetAve(),2)+"," + DoubleToString(bestL1Profit.GetProfit(),2);
    temp += "   "+ bestL2.pnode.name + "(" + IntegerToString(bestL2.node_id)+")=" + DoubleToString(bestL2.GetAve(),2)+"," + DoubleToString(bestL2.GetProfit(),2);
    temp += "..."+bestL2Profit.pnode.name + "(" + IntegerToString(bestL2Profit.node_id)+")=" + DoubleToString(bestL2Profit.GetAve(),2)+"," + DoubleToString(bestL2Profit.GetProfit(),2);
    temp += "   "+ bestL3.pnode.name + "(" + IntegerToString(bestL3.node_id)+")=" + DoubleToString(bestL3.GetAve(),2)+"," + DoubleToString(bestL3.GetProfit(),2);
    temp += "..."+bestL3Profit.pnode.name + "(" + IntegerToString(bestL3Profit.node_id)+")=" + DoubleToString(bestL3Profit.GetAve(),2)+"," + DoubleToString(bestL3Profit.GetProfit(),2);
    return temp;
}
void Owner::ResetAxons(void)
{
    for(int i=0; i<axonsL1.Count(); i++)
        axonsL1.at(i).ResetGain();
    for(int i=0; i<axonsL2.Count(); i++)
        axonsL2.at(i).ResetGain();
    for(int i=0; i<axonsL3.Count(); i++)
        axonsL3.at(i).ResetGain();

}