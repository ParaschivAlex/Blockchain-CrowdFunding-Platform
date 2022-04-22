// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.5;
 
contract CrowdFundingPlatform {
    address public admin;
    uint public nrContribuitori;
    uint public deadline; //timestamp in secunde
    uint public sumaStransaPerTotal;
    uint public goal; 
    uint public contributieMinima; 
    mapping(address => uint) public contribuitori;
    
    struct CererePlata { //atributele unei cereri
        address payable beneficiar; //beneficiarul care primeste banii
        string descriere;
        bool completat; //default=false
        bool cerereInitializata; //default false o fac true cand se face o cerere
        uint suma; //suma in wei trimisa catre beneficiar     
        uint nrVotanti; //numarul de contribuitori ce au votat PENTRU cerere
        mapping(address => bool) votanti; //lista de contribuitori care au votat, initial fiecare are adresa false si dupa vot devine true
    }
    
    mapping(uint => CererePlata) public cereriPlati; //map/variabila pentru a stoca cererile
    //cheia este numarul cererii de plata (indexul) - incepe de la 0, valoarea fiind de tip struct CererePlata
    uint public nrCererePlata; //necesar pt indexarea mapping-ului (nu face automat)

    constructor(uint _deadline, uint _goal) {
        admin = msg.sender;     
        deadline = block.timestamp + _deadline; //adaug nr de secunde la timpul curent
        goal = _goal;
        contributieMinima = 300 wei;
    }
    
    modifier esteAdmin() { //pt creareCererePlata si efectuarePlata, pt ca doar adminul sa poata apela functiile
        require(msg.sender == admin, "Nu aveti drepturile necesare pentru a executa cerinta!");
        _; //pentru a crea functia modifier (se apeleaza dupa ce verifica ca este admin)
    }
    
    event CreareCererePlataEvent(uint _suma, address _beneficiar, string _descriere);
    event EfectuarePlataEvent(uint _suma, address _beneficiar);
    event ContribuieEvent(uint _suma, address _contribuitor); //event => emit
    //punem detaliile platilor ca logs in blockchain. 
    
    function creareCererePlata(uint _suma, address payable _beneficiar,  string memory _descriere) public esteAdmin { //args pt initializare struct CrerePlata
        CererePlata storage cererePlataNoua = cereriPlati[nrCererePlata];//var stocata in "storage", ii se asigneaza o valore din map-ul de cereri
        //daca nu este specificata locatia variabilei sau e speficiata ca fiind in "memory", va da eroare pt ca struct-ul contine un map nested
        //default nrCererePlata = 0 fiind de tip uint, deci map-ul de cereri incepe de la 0
        cererePlataNoua.suma = _suma; //setarea valorilor pt cererea actuala
        cererePlataNoua.beneficiar = _beneficiar;
        cererePlataNoua.descriere = _descriere;
        cererePlataNoua.nrVotanti = 0;
        cererePlataNoua.completat = false;
        cererePlataNoua.cerereInitializata = true; 
        nrCererePlata++; //crestem pt urmatoarea cerere

        emit CreareCererePlataEvent(_suma, _beneficiar, _descriere);
    }
      
    function efectuarePlata(uint _numarCerere) public esteAdmin { //functie pentru a efectua plata pentru care au fost stransi banii
        CererePlata storage cererePlataCurenta = cereriPlati[_numarCerere]; //luam cererea pentru care se efectueaza plata
        require(cererePlataCurenta.cerereInitializata == true, "Cererea nu exista!"); //check daca exista cererea
        require(cererePlataCurenta.nrVotanti > nrContribuitori / 2, "Este nevoie de cel putin 50% dintre contribuitori sa voteze pentru a efectua plata!");//check daca avem jumatate + 1 dinter contrib care au votat
        require(cererePlataCurenta.completat == false, "Cererea a fost deja finalizata!"); //check daca cererea nu este deja completata
        require(cererePlataCurenta.suma <= getSold(), "Sold insuficient"); //check daca exista cererea
        cererePlataCurenta.beneficiar.transfer(cererePlataCurenta.suma); //efectuam plata
        cererePlataCurenta.completat = true; //si o marcam ca si completata
        
        emit EfectuarePlataEvent(cererePlataCurenta.suma, cererePlataCurenta.beneficiar);
    }
    
    function votareCerere(uint _numarCerere) public { //functie pentru votarea cererilor de catre contribuitori
        require(contribuitori[msg.sender] > 0, "Trebuie sa contribuiti pentru a putea vota!"); //check daca userul este contribuitor
        CererePlata storage cererePlataCurenta = cereriPlati[_numarCerere]; //luam cererea pentru care contribuitorul voteaza
        require(cererePlataCurenta.cerereInitializata == true, "Cererea nu exista!"); //check daca exista cererea
        require(cererePlataCurenta.votanti[msg.sender] == false, "Ati votat deja!"); //check daca contribuitorul a votat deja
        cererePlataCurenta.nrVotanti++; //crestem numarul de voturi
        cererePlataCurenta.votanti[msg.sender] = true; //schimbam in true adresa votantului(contribuitorului) pentru a stii ca votat
        
    }
     
    function contribuie() public payable { //functie ce este apelata cand un user contribuie cu cel putin suma minima predefinita
        require(msg.value >= contributieMinima, "Nu ati atins contributia minima!"); //check daca a fost atinsa suma minima pentru a contribui  
        require(block.timestamp < deadline, "Deadline-ul a fost depasit!"); //check daca deadline-ul s-a terminat
        if(contribuitori[msg.sender] == 0) { //daca un user/adresa contribuie pentru prima data atunci crestem numarul de contribuitori
            nrContribuitori++;
        }   
        contribuitori[msg.sender] += msg.value; //adaugam contribuitorul si detaliile la map
        sumaStransaPerTotal += msg.value; //adaugam suma la suma totala
        
        emit ContribuieEvent(msg.value, msg.sender);
    }
    
    function getSold() public view returns(uint) { //returneaza soldul (valoarea totala a contractului)
        return address(this).balance;
    }
    
    function getRefund() public { // functie pt ca un contribuitor sa ceeara un refund (daca sunt indeplinite cerintele)
        require(contribuitori[msg.sender] > 0, "Trebuie sa contribuiti pentru a putea cere un refund!"); //doar un contribuitor poate cere un refund
        require(sumaStransaPerTotal < goal, "Goal-ul a fost strans cu succes!");//check daca nu s-a strans goalul deja
        require(block.timestamp > deadline, "Nu s-a depasit deadline-ul inca!"); //check daca s-a depasit deadline-ul
        address payable beneficiar = payable(msg.sender); //declaram adresa ce va primi suma de la refund
        uint suma = contribuitori[msg.sender]; //luam suma care a fost trimisa de acea adresa pentru a face refund-ul
        beneficiar.transfer(suma); //facem refund-ul

        contribuitori[msg.sender] = 0; //dupa refund setam ca userul a trimis 0 bani
    }
    
    
}