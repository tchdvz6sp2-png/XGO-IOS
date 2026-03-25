//
//  ShowModeVC.swift
//  xgo
//
//  Created by 袋文麟 on 2021/7/21.
//

import UIKit
import RxSwift
import RxCocoa
import RxDataSources

class ShowModeVC: UIViewController,UICollectionViewDelegate{

    @IBOutlet weak var backBtn: UIButton!
    @IBOutlet weak var showBtnsCollectionView: UICollectionView!
        
    let _bag: DisposeBag = DisposeBag()
    
    let dataItem = [
        NSLocalizedString("action.lie_down", comment: ""),
        NSLocalizedString("action.stand_up", comment: ""),
        NSLocalizedString("action.crawl", comment: ""),
        NSLocalizedString("action.spin", comment: ""),
        NSLocalizedString("action.mark_time", comment: ""),
        NSLocalizedString("action.squat", comment: ""),
        NSLocalizedString("action.roll_rotate", comment: ""),
        NSLocalizedString("action.pitch_rotate", comment: ""),
        NSLocalizedString("action.yaw_rotate", comment: ""),
        NSLocalizedString("action.three_axis", comment: ""),
        NSLocalizedString("action.pee", comment: ""),
        NSLocalizedString("action.sit_down", comment: ""),
        NSLocalizedString("action.wave_hand", comment: ""),
        NSLocalizedString("action.stretch", comment: ""),
        NSLocalizedString("action.wave_body", comment: ""),
        NSLocalizedString("action.sway", comment: ""),
        NSLocalizedString("action.beg", comment: ""),
        NSLocalizedString("action.find_food", comment: ""),
        NSLocalizedString("action.shake_hands", comment: ""),
        // Rider extended actions (20-24)
        NSLocalizedString("action.push_up", comment: ""),
        NSLocalizedString("action.look_around", comment: ""),
        NSLocalizedString("action.dance1", comment: ""),
        NSLocalizedString("action.dance2", comment: ""),
        NSLocalizedString("action.balance_demo", comment: "")
    ]
    
    var _vm:ShowModeVM!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        _vm = ShowModeVM(input: ShowModeVM.Input(
            backClick: backBtn.rx.tap.asObservable(),
            itemSelect: showBtnsCollectionView.rx.itemSelected.asObservable()
        ))
        
        _vm.output.back.subscribe { (string) in
                self.navigationController?.popViewController(animated: true)
        }.disposed(by: _bag)
        _vm.output.itemSelectResult.subscribe { (string) in
            print(NSLocalizedString("general.send_complete", comment: "Command sent"))
        }.disposed(by: _bag)
        
        let items = Observable.just([SectionModel(model: "", items: dataItem)])
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.itemSize = CGSize(width: 100, height: 70)
        flowLayout.headerReferenceSize = CGSize(width: self.view.frame.width, height: 40)
        
        showBtnsCollectionView.setCollectionViewLayout(flowLayout, animated: true)
        showBtnsCollectionView.register(UINib(nibName: "ShowModeCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "cell")

        let dataSource = RxCollectionViewSectionedReloadDataSource<SectionModel<String,String>> { (dataSource, cv, indexPath, item) -> UICollectionViewCell in
            let cell = cv.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! ShowModeCollectionViewCell
            cell.lb_title.text = item
//            cell.contentView.addSubview(T##view: UIView##UIView)
            return cell
        }
        // Do any additional setup after loading the view.
        items.bind(to: showBtnsCollectionView.rx.items(dataSource: dataSource))
            .disposed(by: _bag)
        showBtnsCollectionView.rx.setDelegate(self).disposed(by: _bag)
    }

    @IBAction func onResetClick(_ sender: UIButton) {
        FindControlUtil.actionType(type: 0x00)
    }
    @IBAction func onClick(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
    }
}

extension ShowModeVC: UICollectionViewDelegateFlowLayout{
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: (collectionView.frame.size.width-20)/3, height: 50)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0);//分别为上、左、下、右
    }
}
